//
//  FileManagerExtension.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 1/24/19.
//  Copyright © 2019 Tung Nguyen. All rights reserved.
//

import UIKit

extension FileManager {
    func applicationDocumentsDirectory(_ groupName: String = "") -> URL? {
        if groupName.isEmpty {
            return urls(for: .documentDirectory, in: .userDomainMask).first
        }
        return containerURL(forSecurityApplicationGroupIdentifier: groupName)
    }
    
    func createDirectoryIfNeeded(_ path: String, attributes: [FileAttributeKey: Any]? = nil) -> Bool {
        var isDir: ObjCBool = false
        var existing = fileExists(atPath: path, isDirectory:&isDir) && isDir.boolValue
        
        if !existing {
            do {
                try createDirectory(atPath: path, withIntermediateDirectories: true, attributes: attributes)
                existing = true
            } catch {
                print("Failed to create dir at path: \(path) - \(error)")
            }
        }
        return existing
    }
    
    func encryptAESFileAt(_ path: String, newPath: String, key: [UInt8], iv: [UInt8]) -> Bool {
        guard let file = contents(atPath: path),
            let encData = file.toAESencrypted(key, iv: iv) else {return false}
        var success = false
        do {
            try encData.write(to: URL(fileURLWithPath: newPath), options: Data.WritingOptions.completeFileProtection)
            try removeItem(at: URL(fileURLWithPath: path))
            success = true
        } catch {
            print("Failed to decrypt file error - \(error)")
        }
        return success
    }
    
    func decryptAESFileAt(_ path: String, newPath: String, key: [UInt8], iv: [UInt8]) -> Bool {
        guard let file = contents(atPath: path),
            let decData = file.toAESdecrypted(key, iv: iv) else {return false}
        var success = false
        do {
            try decData.write(to: URL(fileURLWithPath: newPath), options: Data.WritingOptions.completeFileProtection)
            try removeItem(at: URL(fileURLWithPath: path))
            success = true
        } catch {
            print("Failed to decrypt file error - \(error)")
        }
        return success
    }
}
