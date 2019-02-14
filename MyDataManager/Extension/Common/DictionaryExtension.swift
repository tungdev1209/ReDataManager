//
//  DictionaryExtension.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 1/24/19.
//  Copyright © 2019 Tung Nguyen. All rights reserved.
//

import UIKit

extension Dictionary {
    func toString() -> String {
        guard let profileData = try? JSONSerialization.data(withJSONObject: self, options: JSONSerialization.WritingOptions.prettyPrinted) else {return ""}
        return profileData.toString()
    }
    
    func toData() -> Data? {
        return try? JSONSerialization.data(withJSONObject: self)
    }
}
