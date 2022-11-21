use anyhow::Result;

use super::{empty_aead::EmptyAead, DeviceKms};

pub struct AndroidKms;

impl DeviceKms for AndroidKms {
    fn new_key_uri(&self) -> Result<String> {
        let device_kms_uri = "enkra-android-kms://version/1/";

        Ok(device_kms_uri.into())
    }

    fn register_kms_client(&self) {
        tink_core::registry::register_kms_client(AndroidKmsClient);
    }
}

impl AndroidKms {
    pub fn new() -> Self {
        AndroidKms
    }
}

// It was supposed to use Android Keystore as device KMS provider to encrypt
// the data here. But Android Keystore is known to be pretty buggy on several phones.
//  * https://github.com/google/tink/issues/535#issuecomment-912170221
//  * https://issuetracker.google.com/issues/176215143
// So we decide to implement a NonEncryption KMS. We use tink keyset as our master
// key manager which can help us to upgrade the cipher schema in a compatible way.
//
// Otherwise, according to https://google.github.io/tink/javadoc/tink-android/HEAD-SNAPSHOT/com/google/crypto/tink/integration/android/AndroidKeysetManager.html
//
// When Android Keystore is disabled or otherwise unavailable, keysets will be stored in cleartext.
// This is not as bad as it sounds because keysets remain inaccessible to any other apps running
// on the same device. Moreover, as of July 2020, most active Android devices support either
// full-disk encryption or file-based encryption, which provide strong security protection against
// key theft even from attackers with physical access to the device. Android Keystore is only useful
// when you want to require user authentication for key use, which should be done if and only if you're
// absolutely sure that Android Keystore is working properly on your target devices.

pub struct AndroidKmsClient;

impl AndroidKmsClient {
    pub const URI_PREFIX: &'static str = "enkra-android-kms://version/1/";
}

impl tink_core::registry::KmsClient for AndroidKmsClient {
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
