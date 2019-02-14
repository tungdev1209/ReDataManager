//
//  BundleExtension.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 1/24/19.
//  Copyright © 2019 Tung Nguyen. All rights reserved.
//

import UIKit

extension Bundle {
    func pathDirectoryURL() -> URL {
        return URL(fileURLWithPath: bundlePath, isDirectory: true)
    }
    
    func getAppUrlSchemes() -> [String] {
        var urls = [String]()
        if let urlTypes = object(forInfoDictionaryKey: "CFBundleURLTypes") as? [Dictionary<String, Any>] {
            for urlType in urlTypes {
                guard let urlSchemes = urlType["CFBundleURLSchemes"] as? [String] else {continue}
                urls.append(contentsOf: urlSchemes)
            }
        }
        return urls
    }
    
    func getAppName() -> String {
        var appName = ""
        if let name = object(forInfoDictionaryKey: "CFBundleName") as? String {
            appName = name
        }
        return appName
    }
    
    func getAppVersion() -> String {
        var version = ""
        if let v = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            version = v
        }
        return version
    }
}
