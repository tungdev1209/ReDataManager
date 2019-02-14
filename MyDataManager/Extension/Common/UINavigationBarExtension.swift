//
//  UINavigationBarExtension.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 1/24/19.
//  Copyright © 2019 Tung Nguyen. All rights reserved.
//

import UIKit

extension UINavigationBar {
    func transparent() {
        setBackgroundImage(UIImage(), for: .default)
        shadowImage = UIImage()
        isTranslucent = true
    }
}
