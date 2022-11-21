use tink_core::Aead;

// Prefix tag format: 1 start byte | 4 bytes tag.
// the start byte is always 1
// This format make our aead output undistinguished with tink key_id prefixed ciphertext.
const TAG_SIZE: usize = 5;

#[derive(Clone)]
pub struct EmptyAeadWithPrefixTag([u8; TAG_SIZE]);

impl EmptyAeadWithPrefixTag {
    pub fn new(tag: u32) -> EmptyAeadWithPrefixTag {
        let mut prefix: [u8; 5] = [0; 5];

        prefix[0] = 1;

        (&mut prefix[1..5]).copy_from_slice(&tag.to_be_bytes());

        EmptyAeadWithPrefixTag(prefix)
    }
}

impl Aead for EmptyAeadWithPrefixTag {
    fn encrypt(
        &self,
        plaintext: &[u8],
        _additional_data: &[u8],
    ) -> Result<Vec<u8>, tink_core::TinkError> {
        let mut ciphertext: Vec<u8> = Vec::with_capacity(plaintext.len() + 5);

        ciphertext.extend_from_slice(&self.0);
        ciphertext.extend_from_slice(&plaintext);

        Ok(ciphertext)
    }

    fn decrypt(
        &self,
        ciphertext: &[u8],
        _additional_data: &[u8],
    ) -> Result<Vec<u8>, tink_core::TinkError> {
        if ciphertext.len() < 5 {
            return Err(tink_core::TinkError::new("invalid ciphertext"));
        }

        let tag = &ciphertext[0..5];

        if tag != self.0 {
            return Err(tink_core::TinkError::new("invalid ciphertext"));
        }

        Ok(ciphertext[5..].to_vec())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_empty_aead_with_prefix_tag() {
        let aead = EmptyAeadWithPrefixTag::new(0);

        let plaintext = tink_core::subtle::random::get_random_bytes(128);

        let ciphertext = aead.encrypt(&plaintext, &[]).unwrap();

        let new_text = aead.decrypt(&ciphertext, &[]).unwrap();

        assert_eq!(plaintext, new_text);
    }
}
