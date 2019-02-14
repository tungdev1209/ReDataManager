//
//  UIDeviceExtension.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 1/24/19.
//  Copyright © 2019 Tung Nguyen. All rights reserved.
//

import UIKit

extension UIDevice {
    static var isIpad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isIphone: Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
}
