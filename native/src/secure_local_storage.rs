use std::path::Path;

use anyhow::{anyhow, bail, Result};
use log_err::LogErrResult;
use pickledb::{PickleDb, PickleDbDumpPolicy, SerializationMethod};
use tink_core::{
    keyset::{self, BinaryReader, BinaryWriter},
    Aead, DeterministicAead,
};

use crate::device_kms::DeviceKms;

pub struct SecureLocalStorage {
    key_deterministic_aead: Box<dyn DeterministicAead>,
    value_aead: Box<dyn Aead>,

    db: PickleDb,
}

// A thread safe hack
unsafe impl Send for SecureLocalStorage {}

impl SecureLocalStorage {
    pub fn get<T: SecureStorable>(&self, key: &str) -> Result<Option<T>> {
        let data = self.get_bytes(key)?;

        match data {
            Some(data) => T::from_bytes(&data).map(|t| Some(t)),
            _ => Ok(None),
        }
    }

    pub fn set<T: SecureStorable>(&mut self, key: &str, value: &T) -> Result<()> {
        if key == Self::KEY_KEYSET_ALIAS || key == Self::VALUE_KEYSET_ALIAS {
            bail!("preserve key");
        }

        let data = value.as_bytes();

        self.set_bytes(key, data)
    }

    fn get_bytes(&self, key: &str) -> Result<Option<Vec<u8>>> {
        let key = self.encrypt_key_name(key)?;

        let key_str = base64::encode(&key);

        let value: Option<Vec<u8>> = self.db.get(&key_str);

        if let Some(v) = value {
            self.value_aead
                .decrypt(&v, &key)
                .map(|v| Some(v))
                .map_err(|e| anyhow!("{}", e))
        } else {
            Ok(None)
        }
    }

    fn set_bytes(&mut self, key: &str, value: &[u8]) -> Result<()> {
        let key = self.encrypt_key_name(key)?;

        let key_str = base64::encode(&key);

        let value = self
            .value_aead
            .encrypt(&value, &key)
            .map_err(|e| anyhow!("{}", e))?;

        self.db
            .set(&key_str, &value)
            .map_err(|e| anyhow!("{}", e))?;

        Ok(())
    }

    fn encrypt_key_name(&self, key: &str) -> Result<Vec<u8>> {
        let key = self
            .key_deterministic_aead
            .encrypt_deterministically(key.as_bytes(), &[])
            .map_err(|e| anyhow!("{}", e))?;

        Ok(key)
    }
}

impl SecureLocalStorage {
    const KEY_KEYSET_ALIAS: &'static str = "__secure_local_storage_key_keyset__";

    const VALUE_KEYSET_ALIAS: &'static str = "__secure_local_storage_value_keyset__";

    const MASTER_KEYSET_ALIAS: &'static str = "__secure_local_storage_master_key__";

    pub fn new<P: AsRef<Path> + Clone>(
        file_path: P,
        device_kms: &Box<dyn DeviceKms>,
    ) -> Result<SecureLocalStorage> {
        let mut db = Self::load_db(file_path);

        let master_key = Self::read_or_generate_master_key(device_kms, Self::MASTER_KEYSET_ALIAS)?;

        let daead_keyset = Self::read_or_generate_key(
            &mut db,
            master_key.box_clone(),
            Self::KEY_KEYSET_ALIAS,
            &tink_daead::aes_siv_key_template(),
        )?;

        let key_deterministic_aead =
            tink_daead::new(&daead_keyset).map_err(|e| anyhow!("{}", e))?;

        let aead_keyset = Self::read_or_generate_key(
            &mut db,
            master_key.box_clone(),
            Self::VALUE_KEYSET_ALIAS,
            &tink_aead::x_cha_cha20_poly1305_key_template(),
        )?;

        let value_aead = tink_aead::new(&aead_keyset).map_err(|e| anyhow!("{}", e))?;

        Ok(SecureLocalStorage {
            key_deterministic_aead,
            value_aead,

            db,
        })
    }

    fn load_db<P: AsRef<Path> + Clone>(db_path: P) -> PickleDb {
        match PickleDb::load(
            db_path.clone(),
            PickleDbDumpPolicy::AutoDump,
            SerializationMethod::Cbor,
        ) {
            Ok(load) => load,
            Err(_) => PickleDb::new(
                db_path,
                PickleDbDumpPolicy::AutoDump,
                SerializationMethod::Cbor,
            ),
        }
    }

    fn read_or_generate_master_key(
        device_kms: &Box<dyn DeviceKms>,
        master_key_alias: &str,
    ) -> Result<Box<dyn Aead>> {
        if !device_kms
            .has_key(master_key_alias)
            .log_expect("DeviceKms has key failed")
        {
            device_kms
                .new_key(master_key_alias)
                .log_expect("DeviceKms new key failed")
        }

        let remote_aead = device_kms
            .aead(master_key_alias)
            .log_expect("DeviceKms aead failed");

        let aead = Box::new(tink_aead::KmsEnvelopeAead::new(
            tink_aead::x_cha_cha20_poly1305_key_template(),
            remote_aead,
        ));

        Ok(aead)
    }

    fn read_or_generate_key(
        db: &mut PickleDb,
        master_key: Box<dyn Aead>,
        key_name: &str,
        key_template: &tink_proto::KeyTemplate,
    ) -> Result<keyset::Handle> {
        let key_name = base64::encode(key_name.as_bytes());

        let value: Option<Vec<u8>> = db.get(&key_name);

        if let Some(value) = value {
            let keyset = keyset::Handle::read(&mut BinaryReader::new(&*value), master_key)
                .map_err(|e| anyhow!("{}", e))?;

            return Ok(keyset);
        }

        let keyset = keyset::Handle::new(key_template).map_err(|e| anyhow!("{}", e))?;

        // store key into db
        let mut value: Vec<u8> = vec![];
        keyset
            .write(&mut BinaryWriter::new(&mut value), master_key)
            .map_err(|e| anyhow!("{}", e))?;
        db.set(&key_name, &value).map_err(|e| anyhow!("{}", e))?;

        Ok(keyset)
    }
}

pub trait SecureStorable {
    fn as_bytes(&self) -> &[u8];

    fn from_bytes(bytes: &[u8]) -> Result<Self>
    where
        Self: Sized;
}

impl SecureStorable for String {
    fn as_bytes(&self) -> &[u8] {
        self.as_bytes()
    }

    fn from_bytes(bytes: &[u8]) -> Result<Self> {
        String::from_utf8(bytes.to_vec()).map_err(|e| e.into())
    }
}

impl SecureStorable for Vec<u8> {
    fn as_bytes(&self) -> &[u8] {
        &self
    }

    fn from_bytes(bytes: &[u8]) -> Result<Self> {
        Ok(bytes.to_vec())
    }
}

#[cfg(test)]
mod tests {
    use std::{cell::RefCell, collections::HashMap};

    use tempfile::tempdir;

    use crate::device_kms::DeviceKms;

    use super::*;

    struct TestKms {
        master_aeads: RefCell<HashMap<String, Box<dyn Aead>>>,
    }

    impl DeviceKms for TestKms {
        fn new_key(&self, key_alias: &str) -> Result<()> {
            let master_keyset =
                keyset::Handle::new(&tink_aead::x_cha_cha20_poly1305_key_template())
                    .map_err(|e| anyhow!("{}", e))?;

            let master_aead = tink_aead::new(&master_keyset).map_err(|e| anyhow!("{}", e))?;

            self.master_aeads
                .borrow_mut()
                .insert(key_alias.to_owned(), master_aead);

            Ok(())
        }

        fn has_key(&self, key_alias: &str) -> Result<bool> {
            Ok(self.master_aeads.borrow().contains_key(key_alias))
        }

        fn aead(&self, key_alias: &str) -> Result<Box<dyn Aead>> {
            let aeads = self.master_aeads.borrow();

            let aead = aeads.get(key_alias).unwrap();

            Ok(aead.box_clone())
        }
    }

    impl TestKms {
        fn new() -> Self {
            TestKms {
                master_aeads: RefCell::new(HashMap::new()),
            }
        }
    }

    #[test]
    fn it_works() {
        tink_aead::init();
        tink_daead::init();

        let tmp_dir = tempdir().unwrap();

        let db_path = tmp_dir.path().join("kv.db");

        let device_kms: Box<dyn DeviceKms> = Box::new(TestKms::new());

        let mut secure_local_storage = SecureLocalStorage::new(db_path, &device_kms).unwrap();

        secure_local_storage.set("key1", &"123".to_owned()).unwrap();
        secure_local_storage.set("key2", &"456".to_owned()).unwrap();

        let bytes = tink_core::subtle::random::get_random_bytes(32);
        secure_local_storage.set("bkey1", &bytes).unwrap();

        let value1: String = secure_local_storage.get("key1").unwrap().unwrap();
        assert_eq!(value1, "123");

        let value2: String = secure_local_storage.get("key2").unwrap().unwrap();
        assert_eq!(value2, "456");

        let value3: Option<String> = secure_local_storage.get("key3").unwrap();
        assert_eq!(value3, None);

        let bytes1: Vec<u8> = secure_local_storage.get("bkey1").unwrap().unwrap();
        assert_eq!(bytes1, bytes);
    }

    #[test]
    fn change_value() {
        tink_aead::init();
        tink_daead::init();

        let tmp_dir = tempdir().unwrap();

        let db_path = tmp_dir.path().join("kv.db");

        let device_kms: Box<dyn DeviceKms> = Box::new(TestKms::new());

        let mut secure_local_storage = SecureLocalStorage::new(db_path, &device_kms).unwrap();

        secure_local_storage.set("key1", &"123".to_owned()).unwrap();

        let value1: String = secure_local_storage.get("key1").unwrap().unwrap();
        assert_eq!(value1, "123");

        secure_local_storage.set("key1", &"456".to_owned()).unwrap();

        let value1: String = secure_local_storage.get("key1").unwrap().unwrap();
        assert_eq!(value1, "456");
    }

    #[test]
    fn reload_db() {
        tink_aead::init();
        tink_daead::init();

        let tmp_dir = tempdir().unwrap();

        let db_path = tmp_dir.path().join("kv.db");

        let device_kms: Box<dyn DeviceKms> = Box::new(TestKms::new());

        let bytes = tink_core::subtle::random::get_random_bytes(32);

        {
            let mut secure_local_storage =
                SecureLocalStorage::new(db_path.clone(), &device_kms).unwrap();

            secure_local_storage.set("key1", &bytes).unwrap();
            let value1: Vec<u8> = secure_local_storage.get("key1").unwrap().unwrap();
            assert_eq!(value1, bytes);
        }

        //reload db
        {
            let secure_local_storage =
                SecureLocalStorage::new(db_path.clone(), &device_kms).unwrap();

            let value1: Vec<u8> = secure_local_storage.get("key1").unwrap().unwrap();
            assert_eq!(value1, bytes);
        }
    }
}
