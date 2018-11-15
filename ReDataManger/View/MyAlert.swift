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
    private var _title: String = AppName
    private var _completion: (() -> Void)?
    private var _animated: Bool = true
    
    class func create(_ message: String?) -> MyAlert {
        let myAlert = MyAlert()
        myAlert.alert = UIAlertController(title: myAlert._title, message: message, preferredStyle: UIAlertController.Style.alert)
        return myAlert
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
        _completion = compl
        return self
    }
    
    func animated(_ animate: Bool) -> MyAlert {
        _animated = animate
        return self
    }
    
    func present(_ vc: UIViewController) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else {return}
                self.present(vc)
            }
            return
        }
        vc.present(self.alert, animated: self._animated, completion: self._completion)
    }
    
    deinit {
        print("MyAlert - DEALLOC")
    }
}

import AVFoundation
class MyPlayerView: UIView {
    var player: AVPlayer! {
        get {
            return (layer as! AVPlayerLayer).player
        }
        set(newPlayer) {
            (layer as! AVPlayerLayer).player = newPlayer
        }
    }
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}
