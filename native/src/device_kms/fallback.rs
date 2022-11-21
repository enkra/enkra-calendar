use anyhow::Result;

use super::{DeviceKms, EmptyAead};

// A KMS do nothing
pub struct EmptyKms;

impl DeviceKms for EmptyKms {
    fn new_key_uri(&self) -> Result<String> {
        Ok("enkra-fallback-kms://".into())
    }

    fn register_kms_client(&self) {
        tink_core::registry::register_kms_client(FallbackKmsClient);
    }
}

impl EmptyKms {
    pub fn new() -> Self {
        Self
    }
}

pub struct FallbackKmsClient;

impl FallbackKmsClient {
    pub const URI_PREFIX: &'static str = "enkra-fallback-kms://";
}

impl tink_core::registry::KmsClient for FallbackKmsClient {
    fn supported(&self, key_uri: &str) -> bool {
        key_uri.starts_with(Self::URI_PREFIX)
    }

    fn get_aead(&self, key_uri: &str) -> Result<Box<dyn tink_core::Aead>, tink_core::TinkError> {
        if !self.supported(key_uri) {
            return Err("unsupported key_uri".into());
        }

        Ok(Box::new(EmptyAead::new()))
    }
}
