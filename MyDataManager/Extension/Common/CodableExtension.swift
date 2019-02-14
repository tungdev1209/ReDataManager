//
//  CodableExtension.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 1/24/19.
//  Copyright © 2019 Tung Nguyen. All rights reserved.
//

import UIKit

extension KeyedDecodingContainer {
    func decode<T>(_ key: KeyedDecodingContainer<K>.Key, defaultValue: T) -> T {
        var model: T!
        do {
            switch defaultValue.self {
            case is Bool:
                model = try decode(Bool.self, forKey: key) as? T
                
            case is Int:
                model = try decode(Int.self, forKey: key) as? T
                
            case is String:
                model = try decode(String.self, forKey: key) as? T
                
            case is Double:
                model = try decode(Double.self, forKey: key) as? T
                
            default:
                model = try decode(Float.self, forKey: key) as? T
            }
        } catch {
            model = defaultValue
        }
        return model
    }
    
    func decode<T: Codable>(_ key: KeyedDecodingContainer<K>.Key, defaultType: T.Type) -> T? {
        var model: T?
        do {
            model = try decode(defaultType.self, forKey: key)
        } catch {
            print("Failed to decode \(key)")
        }
        return model
    }
}

extension Encodable {
    func toString() -> String {
        let data = try? JSONEncoder().encode(self)
        return data == nil ? "" : data!.toString()
    }
}
