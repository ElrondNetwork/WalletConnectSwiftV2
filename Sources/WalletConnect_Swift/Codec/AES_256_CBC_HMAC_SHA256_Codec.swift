// 

import Foundation
import CryptoSwift

protocol Codec {
    func encode(plainText: String, agreementKeys: X25519AgreementKeys) throws -> EncryptionPayload
    func decode(payload: EncryptionPayload, symmetricKey: Data) throws -> String
}

class AES_256_CBC_HMAC_SHA256_Codec: Codec {
    func encode(plainText: String, agreementKeys: X25519AgreementKeys) throws -> EncryptionPayload {
        let (encryptionKey, authenticationKey) = getKeyPair(from: agreementKeys.sharedKey)
        let plainTextData = try data(string: plainText)
        let (cipherText, iv) = try encrypt(key: encryptionKey, data: plainTextData)
        let dataToMac = iv + agreementKeys.publicKey + cipherText
        let hmac = try authenticationCode(key: authenticationKey, data: dataToMac)
        return EncryptionPayload(iv: iv.toHexString(),
                                 publicKey: agreementKeys.publicKey.toHexString(),
                                 mac: hmac.toHexString(),
                                 cipherText: cipherText.toHexString())
    }
    
    func decode(payload: EncryptionPayload, symmetricKey: Data) throws -> String {
        let (decryptionKey, authenticationKey) = getKeyPair(from: symmetricKey)
        let dataToMac = Data(hex: payload.iv) + Data(hex: payload.publicKey) + Data(hex: payload.cipherText)
        let hmac = try authenticationCode(key: authenticationKey, data: dataToMac)
        guard hmac == Data(hex: payload.mac) else {
            throw CodecError.macAuthenticationFailed
        }
        let plainTextData = try decrypt(key: decryptionKey, data: Data(hex: payload.cipherText), iv: Data(hex: payload.iv))
        let plainText = try string(data: plainTextData)
        return plainText
    }

    private func encrypt(key: Data, data: Data) throws -> (cipherText: Data, iv: Data) {
        let iv = AES.randomIV(AES.blockSize)
        let cipher = try AES(key: key.bytes, blockMode: CBC(iv: iv))
        let cipherText = try cipher.encrypt(data.bytes)
        return (Data(cipherText), Data(iv))
    }

    private func decrypt(key: Data, data: Data, iv: Data) throws -> Data {
        let cipher = try AES(key: key.bytes, blockMode: CBC(iv: iv.bytes))
        let plainText = try cipher.decrypt(data.bytes)
        return Data(plainText)
    }

    private func authenticationCode(key: Data, data: Data) throws -> Data {
        let algo = HMAC(key: key.bytes, variant: .sha256)
        let digest = try algo.authenticate(data.bytes)
        return Data(digest)
    }

    private func data(string: String) throws -> Data {
        if let data = string.data(using: .utf8) {
            return data
        } else {
            throw CodecError.stringToDataFailed(string)
        }
    }

    private func string(data: Data) throws -> String {
        if let string = String(data: data, encoding: .utf8) {
            return string
        } else {
            throw CodecError.dataToStringFailed(data)
        }
    }

    private func getKeyPair(from keyData: Data) -> (Data, Data) {
        let keySha512 = keyData.sha512()
        let key1 = keySha512.subdata(in: 0..<32)
        let key2 = keySha512.subdata(in: 32..<64)
        return (key1, key2)
    }
}
