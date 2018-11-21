//
//  MyAlert.swift
//  WALLETIOS
//
//  Created by Tung Nguyen on 10/23/18.
//  Copyright © 2018 GESDEV. All rights reserved.
//

import UIKit

class MyAlert {
    private var alert: UIAlertController!
    var title: String = Bundle.main.getAppName()
    var completion: (() -> Void)?
    var animated: Bool = true
    
    convenience init(_ message: String?) {
        self.init()
        alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    }
    
    func title(_ title: String) -> MyAlert {
        alert.title = title
        return self
    }
    
    func action(_ title: String?, style: UIAlertAction.Style, handler: ((UIAlertAction) -> Void)? = nil) -> MyAlert {
        let alertAction = UIAlertAction(title: title, style: style, handler: handler)
        alert.addAction(alertAction)
        return self
    }
    
    func completion(_ compl: (() -> Void)?) -> MyAlert {
        completion = compl
        return self
    }
    
    func animated(_ animate: Bool) -> MyAlert {
        animated = animate
        return self
    }
    
    func present(_ vc: UIViewController) {
        if !Thread.isMainThread {
            DispatchQueue.main.sync { [weak self] in
                guard let `self` = self else {return}
                self.present(vc)
            }
            return
        }
        vc.present(alert, animated: animated, completion: completion)
    }
    
    deinit {
        print("MyAlert - DEALLOC")
    }
}
