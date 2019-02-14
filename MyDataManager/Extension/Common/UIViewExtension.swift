//
//  UIViewExtension.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 1/24/19.
//  Copyright © 2019 Tung Nguyen. All rights reserved.
//

import UIKit

extension UIView {
    func imageSnapshot() -> UIImage? {
        return imageSnapshotCroppedToFrame()
    }
    
    func imageSnapshotCroppedToFrame(frame: CGRect = .zero) -> UIImage? {
        let scaleFactor = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, scaleFactor)
        drawHierarchy(in: bounds, afterScreenUpdates: true)
        let imageContext: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard var image = imageContext else {return nil}
        
        if !frame.equalTo(CGRect.zero) {
            let scaledRect = frame.applying(CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
            
            if let imageRef = image.cgImage!.cropping(to: scaledRect) {
                image = UIImage(cgImage: imageRef)
            }
        }
        return image
    }
}
