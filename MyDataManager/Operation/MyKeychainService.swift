//
//  MyKeychainStorage.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 11/25/18.
//  Copyright © 2018 Tung Nguyen. All rights reserved.
//

import UIKit

class MyKeyChainConfiguration {
    var serviceId = Bundle.main.bundleIdentifier ?? Bundle.main.getAppName()
    var groupId = ""
    var keyClass = kSecClassGenericPassword
    var accessibilityRule = kSecAttrAccessibleWhenUnlocked
    
    func serviceId(_ id: String) -> MyKeyChainConfiguration {
        serviceId = id
        return self
    }
    
    func groupId(_ id: String) -> MyKeyChainConfiguration {
        groupId = id
        return self
    }
    
    func keyClass(_ kClass: CFString) -> MyKeyChainConfiguration {
        keyClass = kClass
        return self
    }
    
    func accessibilityRule(_ accessRule: CFString) -> MyKeyChainConfiguration {
        accessibilityRule = accessRule
        return self
    }
}

class MyKeychainService {
    static let shared = MyKeychainService()
    
    var configuration: MyKeyChainConfiguration!
    
    func save(key: String, value: String) -> Bool {
        guard let _ = configuration,
            let dataFromString = value.data(using: String.Encoding.utf8) else {return false}
        
        // Instantiate a new default keychain query
        let keychainQuery = NSMutableDictionary()
        if !configuration.groupId.isEmpty {
            keychainQuery[kSecAttrAccessGroup as String] = configuration.groupId
        }
        keychainQuery[kSecClass as String] = configuration.keyClass
        keychainQuery[kSecAttrService as String] = configuration.serviceId
        keychainQuery[kSecAttrAccount as String] = key
        keychainQuery[kSecAttrAccessible as String] = configuration.accessibilityRule
        
        // Search for the keychain items
        let statusSearch: OSStatus = SecItemCopyMatching(keychainQuery, nil)
        
        // if found => update
        if statusSearch == errSecSuccess {
            let attributesToUpdate = NSMutableDictionary()
            attributesToUpdate[kSecValueData as String] = dataFromString
            
            if SecItemUpdate(keychainQuery, attributesToUpdate) != errSecSuccess {
                print("tokens not updated")
                return false
            }
        }
        else if statusSearch == errSecItemNotFound { // if new, add
            keychainQuery[kSecValueData as String] = dataFromString
            if SecItemAdd(keychainQuery, nil) != errSecSuccess {
                print("tokens not saved")
                return false
            }
        }
        else { // error case
            return false
        }
        
        return true
    }
    
    func delete(key: String) -> Bool {
        guard let _ = configuration else {return false}
        
        let keychainQuery = NSMutableDictionary()
        if !configuration.groupId.isEmpty {
            keychainQuery[kSecAttrAccessGroup as String] = configuration.groupId
        }
        keychainQuery[kSecClass as String] = configuration.keyClass
        keychainQuery[kSecAttrService as String] = configuration.serviceId
        keychainQuery[kSecAttrAccount as String] = key
        keychainQuery[kSecAttrAccessible as String] = configuration.accessibilityRule
        
        return SecItemDelete(keychainQuery) == noErr
    }
    
    func read(key: String) -> String {
        guard let _ = configuration else {return ""}
        
        let keychainQuery = NSMutableDictionary()
        if !configuration.groupId.isEmpty {
            keychainQuery[kSecAttrAccessGroup as String] = configuration.groupId
        }
        keychainQuery[kSecClass as String] = configuration.keyClass
        keychainQuery[kSecAttrService as String] = configuration.serviceId
        keychainQuery[kSecAttrAccount as String] = key
        keychainQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        keychainQuery[kSecReturnData as String] = kCFBooleanTrue
        keychainQuery[kSecAttrAccessible as String] = configuration.accessibilityRule
        
        var dataTypeRef: AnyObject?
        // Search for the keychain items
        let status = withUnsafeMutablePointer(to: &dataTypeRef) {
            SecItemCopyMatching(keychainQuery as CFDictionary, UnsafeMutablePointer($0))
        }
        
        if status == errSecItemNotFound {
            print("\(key) not found")
            return ""
        }
        else if status != errSecSuccess {
            print("Error attempting to retrieve \(key) with error code \(status) ")
            return ""
        }
        
        guard let keychainData = dataTypeRef as? Data else {
            return ""
        }
        
        return String(data: keychainData, encoding: String.Encoding.utf8) ?? ""
    }
    
    func resetKeychain() -> Bool {
        guard let _ = configuration else {return false}
        return deleteAllKeysForSecClass(secClass: kSecClassGenericPassword) &&
            deleteAllKeysForSecClass(secClass: kSecClassInternetPassword) &&
            deleteAllKeysForSecClass(secClass: kSecClassCertificate) &&
            deleteAllKeysForSecClass(secClass: kSecClassKey) &&
            deleteAllKeysForSecClass(secClass: kSecClassIdentity)
    }
    
    func deleteAllKeysForSecClass(secClass: CFTypeRef) -> Bool {
        guard let _ = configuration else {return false}
        
        let keychainQuery = NSMutableDictionary()
        keychainQuery[kSecClass as String] = secClass
        let result: OSStatus = SecItemDelete(keychainQuery)
        return result == errSecSuccess
    }
}
