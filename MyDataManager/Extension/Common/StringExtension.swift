//
//  StringExtension.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 1/24/19.
//  Copyright © 2019 Tung Nguyen. All rights reserved.
//

import UIKit
import CommonCrypto

extension String {
    func localize() -> String {
        return NSLocalizedString(self, comment: "")
    }
    
    func postFix(_ number: Int) -> String {
        if isEmpty {return ""}
        let fromIndex = index(endIndex, offsetBy: (-1)*number)
        return String(self[fromIndex...])
    }
    
    var isValidEmail: Bool {
        if isEmpty {return false}
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}"
        let pred = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return pred.evaluate(with: self)
    }
    
    func isValidAppDeepLinkUrl(_ bundle: Bundle? = nil) -> Bool {
        var urls = [String]()
        if let bundle = bundle {
            urls = bundle.getAppUrlSchemes()
        }
        else {
            urls = Bundle.main.getAppUrlSchemes()
        }
        if urls.count > 0, urls.contains(self) {
            return true
        }
        return false
    }
    
    func toData() -> Data? {
        return data(using: String.Encoding.utf8)
    }
    
    func toSHA256(key: String = "") -> String {
        if key.isEmpty {
            let sha2 = self.data(using: String.Encoding.utf8)?.toSHA256()
            return sha2?.map { String(format: "%02hhx", $0) }.joined() ?? ""
        }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), key, key.count, self, count, &digest)
        let data = Data(bytes: digest)
        return data.map { String(format: "%02hhx", $0) }.joined()
    }
    
    func asFilePath(_ fileManagerObject: FileManager = FileManager.default) -> StringFilePath {
        return StringFilePath(path: self, fileManager: fileManagerObject)
    }
    
    func asBundleFile(with fileExtension: String, bundle: Bundle = Bundle.main) -> StringBundleFile {
        return StringBundleFile(name: self, ext: fileExtension, bundle: bundle)
    }
}

struct StringFilePath {
    let path: String
    let fileManager: FileManager
    
    var isFile: Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue
    }
    
    var isDirectory: Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
    
    func stringContent() -> String {
        var content = ""
        if isFile, let data = dataContent() {
            content = data.toString()
        }
        return content
    }
    
    func dataContent() -> Data? {
        return fileManager.contents(atPath: path)
    }
    
    func remove() -> Bool {
        if !isFile {return true}
        var result = false
        do {
            try fileManager.removeItem(at: URL(fileURLWithPath: path))
            result = true
        } catch {
            print("Failed to remove file at \(self)")
        }
        return result
    }
}

struct StringBundleFile {
    let name: String
    let ext: String
    let bundle: Bundle
    
    func stringContent() -> String {
        guard let path = bundle.path(forResource: name, ofType: ext) else {return ""}
        return (try? String(contentsOfFile: path, encoding: String.Encoding.utf8)) ?? ""
    }
    
    func dataContent() -> Data? {
        guard let path = bundle.path(forResource: name, ofType: ext) else {return nil}
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }
}
