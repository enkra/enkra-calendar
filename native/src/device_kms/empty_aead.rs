use tink_core::Aead;

#[derive(Clone)]
pub struct EmptyAead;

impl EmptyAead {
    pub fn new() -> EmptyAead {
        EmptyAead
    }
}

impl Aead for EmptyAead {
    fn encrypt(
        &self,
        plaintext: &[u8],
        _additional_data: &[u8],
    ) -> Result<Vec<u8>, tink_core::TinkError> {
        Ok(plaintext.to_vec())
    }

    fn decrypt(
        &self,
        ciphertext: &[u8],
        _additional_data: &[u8],
    ) -> Result<Vec<u8>, tink_core::TinkError> {
        Ok(ciphertext.to_vec())
    }
}
