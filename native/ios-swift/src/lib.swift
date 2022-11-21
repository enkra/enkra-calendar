import os
import Foundation

import CryptoKit

@_cdecl("secureEnclaveCreateKey")
func createKey() -> UnsafeMutableRawPointer {
    let key = try! SecureEnclave.P256.KeyAgreement.PrivateKey()

    let k = Unmanaged.passRetained(key.dataRepresentation as AnyObject)
    return k.toOpaque()
}

@_cdecl("secureEnclaveSharedSecret")
func sharedSecret(keyBuf: UnsafeMutablePointer<UInt8>,
                  keyLen: Int,
                  publicKeyBuf: UnsafeMutablePointer<UInt8>,
                  publicKeyLen: Int) -> UnsafeMutableRawPointer {
    let keyData = Data(bytes: keyBuf, count: keyLen)

    let key = try! SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: keyData)

    let publicKeyData = Data(bytes: publicKeyBuf, count: publicKeyLen)

    let publicKey = try! P256.KeyAgreement.PublicKey(x963Representation: publicKeyData)

    let secret = try! key.sharedSecretFromKeyAgreement(with: publicKey)

    let s = Unmanaged.passRetained(secret as AnyObject)
    return s.toOpaque()
}

@_cdecl("secureEnclaveDataLen")
func dataLen(d: UnsafeMutableRawPointer) -> Int {
    let ptr = Unmanaged<AnyObject>.fromOpaque(d)

    let data = ptr.takeUnretainedValue() as! Data

    return data.count
}

@_cdecl("secureEnclaveDataCopy")
func dataCopy(d: UnsafeMutableRawPointer, buffer: UnsafeMutablePointer<UInt8>) {

    let ptr = Unmanaged<AnyObject>.fromOpaque(d)

    let data = ptr.takeUnretainedValue() as! Data

    data.copyBytes(to: buffer, count: data.count)
}

@_cdecl("secureEnclaveSharedSecretLen")
func sharedSecretLen(s: UnsafeMutableRawPointer) -> Int {
    let ptr = Unmanaged<AnyObject>.fromOpaque(s)

    let secret = ptr.takeUnretainedValue() as! SharedSecret

    let count = secret.withUnsafeBytes() { bytes in
        bytes.count
    }

    return count
}

@_cdecl("secureEnclaveSharedSecretCopy")
func sharedSecretCopy(s: UnsafeMutableRawPointer, buffer: UnsafeMutableRawPointer) {

    let ptr = Unmanaged<AnyObject>.fromOpaque(s)

    let secret = ptr.takeUnretainedValue() as! SharedSecret

    secret.withUnsafeBytes() { bytes in
        let buf = UnsafeMutableRawBufferPointer(start: buffer, count: bytes.count)
        bytes.copyBytes(to: buf, count: buf.count)
    }
}


@_cdecl("secureEnclaveReleaseObject")
func releaseObject(obj: UnsafeRawPointer) {
    let ptr = Unmanaged<AnyObject>.fromOpaque(obj)

    ptr.release()
}

@_cdecl("secureEnclaveRandomPublicKey")
func randomPublicKey() -> UnsafeMutableRawPointer {
    let key = P256.KeyAgreement.PrivateKey().publicKey

    let k = Unmanaged.passRetained(key.x963Representation as AnyObject)
    return k.toOpaque()
}
