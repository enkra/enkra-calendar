use std::fs::File;
use std::path::Path;

use anyhow::{anyhow, bail, Result};
use log::info;
use log_err::LogErrResult;
use pickledb::{PickleDb, PickleDbDumpPolicy, SerializationMethod};
use tink_core::{
    keyset::{self, BinaryReader, BinaryWriter},
    Aead, DeterministicAead,
};

use crate::device_kms::{DeviceKms, EmptyAead};

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
        if key == Self::KEY_KEYSET_ALIAS
            || key == Self::VALUE_KEYSET_ALIAS
            || key == Self::VERSION_KEY
        {
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

        // dump db here because we load db with DumpUponRequest policy.
        self.db.dump()?;

        Ok(())
    }

    fn encrypt_key_name(&self, key: &str) -> Result<Vec<u8>> {
        let key = self
            .key_deterministic_aead
            .encrypt_deterministically(key.as_bytes(), &[])
            .map_err(|e| anyhow!("{}", e))?;

        Ok(key)
    }

    fn load_or_create_db<P: AsRef<Path> + Clone>(db_path: P) -> PickleDb {
        // load db with DumpUponRequest add dumps call in `set` and `remove`.
        // Remove unnessary dumps to reduce file corrupt risk.
        if !db_path.as_ref().exists() {
            return PickleDb::new(
                db_path,
                PickleDbDumpPolicy::DumpUponRequest,
                SerializationMethod::Cbor,
            );
        }

        PickleDb::load(
            db_path.clone(),
            PickleDbDumpPolicy::DumpUponRequest,
            SerializationMethod::Cbor,
        )
        .log_expect(&format!(
            "load existed secure_local_stoage db error: {}",
            db_path.as_ref().file_name().unwrap().to_string_lossy()
        ))
    }
}

impl SecureLocalStorage {
    const KEY_KEYSET_ALIAS: &'static str = "__secure_local_storage_kms_protected_key_keyset__";

    const VALUE_KEYSET_ALIAS: &'static str = "__secure_local_storage_kms_protected_value_keyset__";

    const VERSION_KEY: &'static str = "__secure_local_storage_version__";

    pub fn new_with_kms<P: AsRef<Path> + Clone>(
        file_path: P,
        device_kms: &Box<dyn DeviceKms>,
        master_key_file: P,
    ) -> Result<SecureLocalStorage> {
        let mut db = Self::load_or_create_db(file_path);

        let version = Self::read_or_generate_version(&mut db)?;

        info!("secure local storage version: {}", version);

        let master_key = Self::read_or_generate_master_key(device_kms, master_key_file)?;

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

    fn read_or_generate_master_key<P: AsRef<Path> + Clone>(
        device_kms: &Box<dyn DeviceKms>,
        master_key_file: P,
    ) -> Result<Box<dyn Aead>> {
        // Add a lock to avoid master key file corruption
        let lock = std::sync::Mutex::new(());

        let _lock = lock.lock().map_err(|e| anyhow!("{}", e))?;

        let master_keyset = if !master_key_file.as_ref().exists() {
            let device_kms_uri = device_kms.new_key_uri()?;

            let keyset = keyset::Handle::new(&tink_aead::kms_envelope_aead_key_template(
                &device_kms_uri,
                tink_aead::x_cha_cha20_poly1305_key_template(),
            ))
            .map_err(|e| anyhow!("{}", e))?;

            // Save master keyset to file
            //
            // We choose EmptyAead to pesudo encrypt the master key
            // because there's no secret information in it
            keyset
                .write(
                    &mut BinaryWriter::new(File::create(master_key_file)?),
                    Box::new(EmptyAead::new()),
                )
                .map_err(|e| anyhow!("{}", e))?;

            keyset
        } else {
            // load master keyset from file
            let keyset = keyset::Handle::read(
                &mut BinaryReader::new(File::open(master_key_file)?),
                Box::new(EmptyAead::new()),
            )
            .map_err(|e| anyhow!("{}", e))?;

            keyset
        };

        Ok(tink_aead::new(&master_keyset).map_err(|e| anyhow!("{}", e))?)
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

    fn read_or_generate_version(db: &mut PickleDb) -> Result<u64> {
        let key_name = base64::encode(Self::VERSION_KEY.as_bytes());

        let value: Option<u64> = db.get(&key_name);

        if let Some(value) = value {
            return Ok(value);
        }

        db.set::<u64>(&key_name, &1).map_err(|e| anyhow!("{}", e))?;
        db.dump()?;

        Ok(1)
    }

    #[cfg(test)]
    fn get_version(&self) -> Option<u64> {
        let key_name = base64::encode(Self::VERSION_KEY.as_bytes());

        let value: Option<u64> = self.db.get(&key_name);

        value
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

    use tempfile::tempdir;

    use crate::device_kms::DeviceKms;

    use super::*;

    pub struct TestKms;

    impl DeviceKms for TestKms {
        fn new_key_uri(&self) -> Result<String> {
            Ok("enkra-test-kms://".into())
        }

        fn register_kms_client(&self) {
            tink_core::registry::register_kms_client(TestKmsClient::new());
        }
    }

    impl TestKms {
        pub fn new() -> Self {
            Self
        }
    }

    pub struct TestKmsClient {
        master_keyset: keyset::Handle,
    }

    impl TestKmsClient {
        pub const URI_PREFIX: &'static str = "enkra-test-kms://";

        fn new() -> Self {
            let master_keyset =
                keyset::Handle::new(&tink_aead::x_cha_cha20_poly1305_key_template()).unwrap();

            Self { master_keyset }
        }
    }

    impl tink_core::registry::KmsClient for TestKmsClient {
        fn supported(&self, key_uri: &str) -> bool {
            key_uri.starts_with(Self::URI_PREFIX)
        }

        fn get_aead(
            &self,
            key_uri: &str,
        ) -> Result<Box<dyn tink_core::Aead>, tink_core::TinkError> {
            if !self.supported(key_uri) {
                return Err("unsupported key_uri".into());
            }

            let master_aead = tink_aead::new(&self.master_keyset)?;

            Ok(master_aead)
        }
    }

    #[test]
    fn it_works() {
        tink_aead::init();
        tink_daead::init();

        let tmp_dir = tempdir().unwrap();

        let db_path = tmp_dir.path().join("kv.db");
        let master_key_path = tmp_dir.path().join("master_key");

        let device_kms: Box<dyn DeviceKms> = Box::new(TestKms::new());
        device_kms.register_kms_client();

        let mut secure_local_storage =
            SecureLocalStorage::new_with_kms(db_path, &device_kms, master_key_path).unwrap();

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
        let master_key_path = tmp_dir.path().join("master_key");

        let device_kms: Box<dyn DeviceKms> = Box::new(TestKms::new());
        device_kms.register_kms_client();

        let mut secure_local_storage =
            SecureLocalStorage::new_with_kms(db_path, &device_kms, master_key_path).unwrap();

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
        let master_key_path = tmp_dir.path().join("master_key");

        let device_kms: Box<dyn DeviceKms> = Box::new(TestKms::new());
        device_kms.register_kms_client();

        let bytes = tink_core::subtle::random::get_random_bytes(32);

        {
            let mut secure_local_storage = SecureLocalStorage::new_with_kms(
                db_path.clone(),
                &device_kms,
                master_key_path.clone(),
            )
            .unwrap();

            secure_local_storage.set("key1", &bytes).unwrap();
            let value1: Vec<u8> = secure_local_storage.get("key1").unwrap().unwrap();
            assert_eq!(value1, bytes);

            assert_eq!(secure_local_storage.get_version().unwrap(), 1);
        }

        //reload db
        {
            let secure_local_storage = SecureLocalStorage::new_with_kms(
                db_path.clone(),
                &device_kms,
                master_key_path.clone(),
            )
            .unwrap();

            let value1: Vec<u8> = secure_local_storage.get("key1").unwrap().unwrap();
            assert_eq!(value1, bytes);

            assert_eq!(secure_local_storage.get_version().unwrap(), 1);
        }
    }
}
