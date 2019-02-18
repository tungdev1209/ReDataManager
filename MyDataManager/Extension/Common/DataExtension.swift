//
//  DataExtension.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 1/24/19.
//  Copyright © 2019 Tung Nguyen. All rights reserved.
//

import UIKit
import CommonCrypto

extension Data {
    func toJSON() -> Any? {
        return try? JSONSerialization.jsonObject(with: self, options: JSONSerialization.ReadingOptions.allowFragments)
    }
    
    func toString() -> String {
        return String(data: self, encoding: .utf8) ?? ""
    }
    
    func toModel<T: Decodable>(_ type: T.Type) -> T? {
        let decoder = JSONDecoder()
        var model: T?
        do {
            model = try decoder.decode(T.self, from: self)
        }
        catch {
            print("Failed to parse \(String(describing: T.self)) - error: \(error)")
        }
        return model
    }
    
    func toSHA256() -> Data? {
        var digestData = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        
        _ = digestData.withUnsafeMutableBytes { digestBytes in
            withUnsafeBytes { bytes in
                CC_SHA256(bytes, CC_LONG(count), digestBytes)
            }
        }
        return digestData
    }
    
    func toAESKey(_ length: Int = kCCKeySizeAES256) -> Data? {
        var status = Int32(0)
        var derivedBytes = [UInt8](repeating: 0, count: length)
        let salt = Data.randomSalt()
        withUnsafeBytes { (passwordBytes: UnsafePointer<Int8>!) in
            salt.withUnsafeBytes { (saltBytes: UnsafePointer<UInt8>!) in
                status = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                              passwordBytes,
                                              count,
                                              saltBytes,
                                              salt.count,
                                              CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                                              10000,
                                              &derivedBytes,
                                              length)
            }
        }
        if status == 0 {
            return Data(bytes: UnsafePointer<UInt8>(derivedBytes), count: length)
        }
        print("Failed to gen key - error: \(status)")
        return nil
    }
    
    func toAESencrypted(_ key: [UInt8], iv: [UInt8]) -> Data? {
        return toAESencrypted(Data.init(bytes: key), iv: Data.init(bytes: iv))
    }
    
    func toAESencrypted(_ key: Data, iv: Data) -> Data? {
        if key.count == 16 {
            return toAEScrypted(key, iv: iv, operation: kCCEncrypt, size: kCCKeySizeAES128)
        }
        if key.count == 32 {
            return toAEScrypted(key, iv: iv, operation: kCCEncrypt, size: kCCKeySizeAES256)
        }
        return toAEScrypted(key, iv: iv, operation: kCCEncrypt, size: kCCKeySizeAES192)
    }
    
    func toAESdecrypted(_ key: [UInt8], iv: [UInt8]) -> Data? {
        return toAESdecrypted(Data(bytes: key), iv: Data(bytes: iv))
    }
    
    func toAESdecrypted(_ key: Data, iv: Data) -> Data? {
        if key.count == 16 {
            return toAEScrypted(key, iv: iv, operation: kCCDecrypt, size: kCCKeySizeAES128)
        }
        if key.count == 32 {
            return toAEScrypted(key, iv: iv, operation: kCCDecrypt, size: kCCKeySizeAES256)
        }
        return toAEScrypted(key, iv: iv, operation: kCCDecrypt, size: kCCKeySizeAES192)
    }
    
    func toAEScrypted(_ key: Data, iv: Data, operation: Int, size: Int) -> Data? {
        let data = self as NSData
        let ivData = iv as NSData
        let keyData = key as NSData
        
        let cryptLength = size_t(data.length + kCCBlockSizeAES128)
        var cryptData = Data(count: cryptLength)
        
        var numBytesCrypted: size_t = 0
        
        let cryptStatus = cryptData.withUnsafeMutableBytes { cryptBytes in
            CCCrypt(CCOperation(operation), //kCCDecrypt
                CCAlgorithm(kCCAlgorithmAES),
                CCOptions(kCCOptionPKCS7Padding),
                keyData.bytes, size_t(size), //kCCKeySizeAES128
                ivData.bytes,
                data.bytes, data.length,
                cryptBytes, cryptLength,
                &numBytesCrypted)
        }
        
        if UInt32(cryptStatus) == UInt32(kCCSuccess) {
            cryptData.removeSubrange(numBytesCrypted..<cryptData.count)
        }
        else {
            print("Failed to crypt - error: \(cryptStatus)")
        }
        
        return cryptData
    }
    
    func toUIImage() -> UIImage? {
        return UIImage(data: self)
    }
    
    static func randomIv() -> Data {
        return random(length: kCCBlockSizeAES128)
    }
    
    static func randomSalt() -> Data {
        return random(length: 8)
    }
    
    static func random(length: Int) -> Data {
        var data = Data(count: length)
        let _ = data.withUnsafeMutableBytes { mutableBytes in
            SecRandomCopyBytes(kSecRandomDefault, length, mutableBytes)
        }
        return data
    }
}
