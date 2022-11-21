use anyhow::Result;

#[cfg(target_os = "android")]
pub mod android;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
pub mod fallback;

mod empty_aead;

pub use empty_aead::EmptyAead;

pub trait DeviceKms {
    fn new_key_uri(&self) -> Result<String>;

    fn register_kms_client(&self);
}
