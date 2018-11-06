//
//  App+Ext.swift
//  ReDataManager
//
//  Created by Tung Nguyen on 10/20/18.
//  Copyright © 2018 Tung Nguyen. All rights reserved.
//

import UIKit

extension UINavigationBar {
    func transparent() {
        setBackgroundImage(UIImage(), for: .default)
        shadowImage = UIImage()
        isTranslucent = true
    }
}

extension Bundle {
    func contentsOfFile(_ fileName: String?, type: String?) -> String? {
        guard let path = path(forResource: fileName, ofType: type) else {return nil}
        return try? String(contentsOfFile: path, encoding: String.Encoding.utf8)
    }
    
    func pathDirectoryURL() -> URL {
        return URL(fileURLWithPath: bundlePath, isDirectory: true)
    }
    
    func getAppUrlSchemes() -> [String] {
        var urls = [String]()
        if let urlSchemesDic = object(forInfoDictionaryKey: "CFBundleURLTypes") as? [Dictionary<String, [String]>],
            let _urls = urlSchemesDic.first?["CFBundleURLSchemes"] {
            urls = _urls
        }
        return urls
    }
}

extension UIDevice {
    func isIpad() -> Bool {
        return userInterfaceIdiom == .pad
    }
    
    func isIphone() -> Bool {
        return userInterfaceIdiom == .phone
    }
}

extension Data {
    func toJSON() -> Any? {
        return try? JSONSerialization.jsonObject(with: self, options: JSONSerialization.ReadingOptions.allowFragments)
    }
    
    func toString() -> String {
        return String(data: self, encoding: .utf8) ?? ""
    }
    
    func toModel<T: Decodable>(_ type: T.Type) -> T? {
        let decoder = JSONDecoder()
        do {
            let model = try decoder.decode(T.self, from: self)
            return model
        }
        catch {
            print("Failed to parse \(String(describing: T.self)) - error: \(error)")
            return nil
        }
    }
}

extension Dictionary {
    func toString() -> String {
        guard let profileData = try? JSONSerialization.data(withJSONObject: self, options: JSONSerialization.WritingOptions.prettyPrinted) else {return ""}
        return profileData.toString()
    }
}

extension KeyedDecodingContainer {
    func decode<T>(_ key: KeyedDecodingContainer<K>.Key, defaultValue: T) -> T {
        do {
            switch defaultValue.self {
            case is Bool:
                return try decode(Bool.self, forKey: key) as! T
                
            case is Int:
                return try decode(Int.self, forKey: key) as! T
                
            case is String:
                return try decode(String.self, forKey: key) as! T
                
            case is Double:
                return try decode(Double.self, forKey: key) as! T
                
            default:
                return try decode(Float.self, forKey: key) as! T
            }
        } catch {
            return defaultValue
        }
    }
}

let UUIDQueue = DispatchQueue.init(label: "com.nsuuid.basetime")
extension NSUUID {
    static func createBaseTime() -> String {
        var uuidString: String = ""
        UUIDQueue.sync {
            let uuidSize = MemoryLayout.size(ofValue: uuid_t.self)
            let uuidPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: uuidSize)
            uuid_generate_time(uuidPointer)
            let uuid = NSUUID(uuidBytes: uuidPointer)
            uuidPointer.deallocate()
            uuidString = uuid.uuidString
        }
        return uuidString
    }
}
