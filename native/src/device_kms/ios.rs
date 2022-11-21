use anyhow::Result;
use tink_aead::subtle::XChaCha20Poly1305;
use tink_core::{Aead, Prf, TinkError};
use tink_prf::subtle::HkdfPrf;
use tink_proto::HashType;

use super::{ios_secure_enclave::SecureEnclaveP256Key, DeviceKms};

pub struct IosKms;

impl DeviceKms for IosKms {
    fn new_key_uri(&self) -> Result<String> {
        let key = SecureEnclaveP256Key::generate_in_hardware();

        let device_kms_uri = format!("enkra-ios-kms://version/1/{}", key.encode_base64());

        Ok(device_kms_uri)
    }

    fn register_kms_client(&self) {
        tink_core::registry::register_kms_client(IosKmsClient);
    }
}

impl IosKms {
    pub fn new() -> Self {
        Self
    }
}

pub struct IosKmsClient;

impl IosKmsClient {
    pub const URI_PREFIX: &'static str = "enkra-ios-kms://version/1/";
}

impl tink_core::registry::KmsClient for IosKmsClient {
    fn supported(&self, key_uri: &str) -> bool {
        key_uri.starts_with(Self::URI_PREFIX)
    }

    fn get_aead(&self, key_uri: &str) -> Result<Box<dyn tink_core::Aead>, tink_core::TinkError> {
        if !self.supported(key_uri) {
            return Err("unsupported key_uri".into());
        }
        let key = if let Some(rest) = key_uri.strip_prefix(Self::URI_PREFIX) {
            rest
        } else {
            key_uri
        };

        let key = SecureEnclaveP256Key::decode_base64(&key)
            .map_err(|e| TinkError::new(&format!("{}", e)))?;

        Ok(Box::new(SecureEnclaveAead::new(key)))
    }
}

// SecureEnclaveDhP256(ios or macOS) + HkdfSha256 + XChaCha20Poly1305
#[derive(Clone)]
struct SecureEnclaveAead {
    key: SecureEnclaveP256Key,
}

impl SecureEnclaveAead {
    pub fn new(key: SecureEnclaveP256Key) -> Self {
        Self { key }
    }

    pub fn symmetric_encryption_key(
        &self,
        public_key: &[u8],
    ) -> Result<Vec<u8>, tink_core::TinkError> {
        let shared_secret = self.key.shared_secret(public_key);

        let hkdf_sha256 = HkdfPrf::new(
            HashType::Sha256,
            &shared_secret,
            b"Enkra iOS SecureEnclave P256 Aead",
        )?;

        let key = hkdf_sha256.compute_prf(b"", 32)?;

        Ok(key)
    }
}

impl Aead for SecureEnclaveAead {
    fn encrypt(
        &self,
        plaintext: &[u8],
        additional_data: &[u8],
    ) -> Result<Vec<u8>, tink_core::TinkError> {
        let mut public_key = SecureEnclaveP256Key::random_public_key();

        let symmetric_key = self.symmetric_encryption_key(&public_key)?;

        let aead = XChaCha20Poly1305::new(&symmetric_key)?;

        let ciphertext = aead.encrypt(plaintext, additional_data)?;

        public_key.extend_from_slice(&ciphertext);

        Ok(public_key)
    }

    fn decrypt(
        &self,
        ciphertext: &[u8],
        additional_data: &[u8],
    ) -> Result<Vec<u8>, tink_core::TinkError> {
        if ciphertext.len() < SecureEnclaveP256Key::PUBLIC_KEY_SIZE {
            return Err(tink_core::TinkError::new("invalid ciphertext"));
        }

        let public_key = &ciphertext[0..SecureEnclaveP256Key::PUBLIC_KEY_SIZE];

        let symmetric_key = self.symmetric_encryption_key(&public_key)?;

        let aead = XChaCha20Poly1305::new(&symmetric_key)?;

        aead.decrypt(
            &ciphertext[SecureEnclaveP256Key::PUBLIC_KEY_SIZE..],
            additional_data,
        )
    }
}
