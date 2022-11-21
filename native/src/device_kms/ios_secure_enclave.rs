use std::ffi::c_void;

use anyhow::Result;

#[derive(Clone)]
pub struct SecureEnclaveP256Key {
    key: Vec<u8>,
}

impl SecureEnclaveP256Key {
    // ANSI x9.63 representation of the P256 public key
    pub const PUBLIC_KEY_SIZE: usize = 65;

    pub fn generate_in_hardware() -> Self {
        let key = unsafe { secureEnclaveCreateKey() };

        let key = SData::new(key);

        SecureEnclaveP256Key { key: key.bytes() }
    }

    pub fn random_public_key() -> Vec<u8> {
        let key = unsafe { secureEnclaveRandomPublicKey() };

        let key = SData::new(key);

        key.bytes()
    }

    pub fn encode_base64(&self) -> String {
        base64::encode_config(&self.key, base64::URL_SAFE_NO_PAD)
    }

    pub fn decode_base64(key: &str) -> Result<Self> {
        let key = base64::decode_config(key, base64::URL_SAFE_NO_PAD)?;

        Ok(Self { key })
    }

    pub fn shared_secret(&self, public_key: &[u8]) -> Vec<u8> {
        let shared_secret = unsafe {
            secureEnclaveSharedSecret(
                self.key.as_ptr(),
                self.key.len() as i32,
                public_key.as_ptr(),
                public_key.len() as i32,
            )
        };

        let shared_secret = SSharedSecret::new(shared_secret);

        shared_secret.bytes()
    }
}

// Swift `Data` struct
struct SData(*mut c_void);

impl SData {
    fn new(ptr: *mut c_void) -> Self {
        SData(ptr)
    }

    fn len(&self) -> usize {
        (unsafe { secureEnclaveDataLen(self.0) }) as usize
    }

    fn bytes(&self) -> Vec<u8> {
        let len = self.len();

        let mut buf: Vec<u8> = Vec::with_capacity(len);

        unsafe { secureEnclaveDataCopy(self.0, buf.as_mut_ptr()) };

        unsafe { buf.set_len(len) };

        buf
    }
}

impl Drop for SData {
    fn drop(&mut self) {
        unsafe { secureEnclaveReleaseObject(self.0) }
    }
}

// Swift `SharedSecret` struct
struct SSharedSecret(*mut c_void);

impl SSharedSecret {
    fn new(ptr: *mut c_void) -> Self {
        SSharedSecret(ptr)
    }

    fn len(&self) -> usize {
        (unsafe { secureEnclaveSharedSecretLen(self.0) }) as usize
    }

    fn bytes(&self) -> Vec<u8> {
        let len = self.len();

        let mut buf: Vec<u8> = Vec::with_capacity(len);

        unsafe { secureEnclaveSharedSecretCopy(self.0, buf.as_mut_ptr()) };

        unsafe { buf.set_len(len) };

        buf
    }
}

impl Drop for SSharedSecret {
    fn drop(&mut self) {
        unsafe { secureEnclaveReleaseObject(self.0) }
    }
}

extern "C" {
    fn secureEnclaveCreateKey() -> *mut c_void;
    fn secureEnclaveDataLen(data: *mut c_void) -> i32;
    fn secureEnclaveDataCopy(data: *mut c_void, buffer: *mut u8);

    fn secureEnclaveSharedSecret(
        keyBuf: *const u8,
        keyLen: i32,
        publicKeyBuf: *const u8,
        publicKeyLen: i32,
    ) -> *mut c_void;
    fn secureEnclaveSharedSecretLen(data: *const c_void) -> i32;
    fn secureEnclaveSharedSecretCopy(data: *const c_void, buffer: *mut u8);

    fn secureEnclaveReleaseObject(obj: *mut c_void);

    fn secureEnclaveRandomPublicKey() -> *mut c_void;
}
