use anyhow::Result;
use tink_core::Aead;

#[cfg(target_os = "android")]
pub mod android;
#[cfg(not(target_os = "android"))]
pub mod desktop;

mod empty_aead;

pub trait DeviceKms {
    fn new_key(&self, key_alias: &str) -> Result<()>;

    fn has_key(&self, key_alias: &str) -> Result<bool>;

    fn aead(&self, key_alias: &str) -> Result<Box<dyn Aead>>;
}
