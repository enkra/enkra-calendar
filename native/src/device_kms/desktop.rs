use anyhow::Result;
use tink_core::Aead;

use super::{empty_aead::EmptyAeadWithPrefixTag, DeviceKms};

// A KMS do nothing
pub struct EmptyKms;

impl DeviceKms for EmptyKms {
    fn new_key(&self, _key_alias: &str) -> Result<()> {
        Ok(())
    }

    fn has_key(&self, _key_alias: &str) -> Result<bool> {
        Ok(true)
    }

    fn aead(&self, _key_alias: &str) -> Result<Box<dyn Aead>> {
        Ok(Box::new(EmptyAeadWithPrefixTag::new(0)))
    }
}

impl EmptyKms {
    pub fn new() -> Self {
        Self
    }
}
