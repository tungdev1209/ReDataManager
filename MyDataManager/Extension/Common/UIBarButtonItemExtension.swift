//
//  UIBarButtonItemExtension.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 1/24/19.
//  Copyright © 2019 Tung Nguyen. All rights reserved.
//

import UIKit

private var kBackItemSelectedBlock: UInt8 = 0
extension UIBarButtonItem {
    typealias ItemAction = ((UIBarButtonItem) -> Void)
    
    var itemSelected: ItemAction? {
        get {
            return objc_getAssociatedObject(self, &kBackItemSelectedBlock) as? ItemAction
        }
        set(item) {
            objc_setAssociatedObject(self, &kBackItemSelectedBlock, item, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func title(_ t: String) -> UIBarButtonItem {
        title = t
        let titleView = UILabel()
        titleView.text = title
        titleView.textColor = UIColor(displayP3Red: 26/255, green: 148/255, blue: 239/255, alpha: 1)
        appendToCustomView(titleView)
        return self
    }
    
    func image(_ i: UIImage?) -> UIBarButtonItem {
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        imageView.image = i
        imageView.contentMode = .scaleAspectFit
        imageView.layer.masksToBounds = true
        appendToCustomView(imageView)
        return self
    }
    
    private func appendToCustomView(_ view: UIView) {
        if customView == nil {
            let itemView = UIStackView(frame: CGRect(x: 0, y: 0, width: 70, height: 0))
            itemView.axis = NSLayoutConstraint.Axis.horizontal
            itemView.alignment = .fill
            itemView.distribution = .fill
            customView = itemView
        }
        guard let stackView = customView as? UIStackView else {return}
        
        // insert new view
        if view is UILabel {
            stackView.addArrangedSubview(view)
        }
        else if view is UIImageView {
            stackView.insertArrangedSubview(view, at: 0)
        }
        
        // adjust stackview width for new view
        var width: CGFloat = 0.0
        var ivView: UIImageView! = nil
        for v in stackView.arrangedSubviews {
            if v is UILabel {
                width += 40.0
            }
            else if let iv = v as? UIImageView {
                ivView = iv
                width += 20.0
            }
        }
        let hasLabel = width == 60.0
        if hasLabel, let _ = ivView {
            var ivWidth: CGFloat = 20.0
            if UIDevice.isIpad {
                ivWidth = 40.0
                width += 20.0
            }
            var ivf = ivView.frame
            ivf.size.width = ivWidth
            ivView.frame = ivf
        }
        stackView.frame = CGRect(x: 0, y: 0, width: width, height: 0)
    }
    
    func selectionBlock(_ block: ItemAction?) -> UIBarButtonItem {
        itemSelected = block
        let tap = UITapGestureRecognizer(target: self, action: #selector(itemAction(_:)))
        customView?.addGestureRecognizer(tap)
        customView?.isUserInteractionEnabled = true
        return self
    }
    
    @objc private func itemAction(_ item: UIBarButtonItem) {
        itemSelected?(item)
    }
}
