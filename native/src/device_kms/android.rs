use anyhow::Result;
use tink_core::Aead;

use super::{empty_aead::EmptyAeadWithPrefixTag, DeviceKms};

// It was supposed to use Android Keystore as device KMS provider to encrypt
// the data here. But Android Keystore is known to be pretty buggy on several phones.
//  * https://github.com/google/tink/issues/535#issuecomment-912170221
//  * https://issuetracker.google.com/issues/176215143
// So we decide to implement a NonEncryption KMS. We add a tag in ciphertext to indicate
// the cipher schema which can help us to upgrade the cipher schema in a compatible way.
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

enum CipherSchema {
    NonEncryption = 0,

    // Not used currently, can enable it in future
    #[allow(dead_code)]
    AndroidKeyStore = 1,
}

const PRIMARY_CIPHER_SCHEMA: CipherSchema = CipherSchema::NonEncryption;

pub struct AndroidKms;

impl DeviceKms for AndroidKms {
    fn new_key(&self, _key_alias: &str) -> Result<()> {
        Ok(())
    }

    fn has_key(&self, _key_alias: &str) -> Result<bool> {
        Ok(true)
    }

    fn aead(&self, _key_alias: &str) -> Result<Box<dyn Aead>> {
        Ok(Box::new(EmptyAeadWithPrefixTag::new(
            PRIMARY_CIPHER_SCHEMA as u32,
        )))
    }
}

impl AndroidKms {
    pub fn new() -> Self {
        AndroidKms
    }
}
