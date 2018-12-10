//
//  MyPlayerController.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 12/8/18.
//  Copyright © 2018 Tung Nguyen. All rights reserved.
//

import UIKit
import AVFoundation

enum MyPlayerError: Error {
    case DidFailToLoadContent
    case DidCancelLoadContent
}

class CleanPlayerBag: NSObject {
    fileprivate(set) weak var controller: MyPlayerController?
    deinit {
        controller?.cleanPlayerBag = nil
    }
}

class MyPlayerController: NSObject {
    private(set) var playerView = MyPlayerView()
    private(set) var playerItem: AVPlayerItem?
    private(set) var error: MyPlayerError?
    
    @objc dynamic fileprivate(set) weak var cleanPlayerBag: CleanPlayerBag?
    
    private(set) var url: URL!
    fileprivate let _id = NSUUID.createBaseTime()
    
    var configuration: MyPlayerConfiguration?
    
    convenience init(_ contentUrl: URL) {
        self.init()
        url = contentUrl
    }
    
    func cleanBy(_ cleanObject: CleanPlayerBag) {
        cleanPlayerBag = cleanObject
        cleanPlayerBag?.controller = self
        addObserver(self, forKeyPath: #keyPath(MyPlayerController.cleanPlayerBag), options: NSKeyValueObservingOptions.new, context: nil)
    }
    
    func configuration(_ config: MyPlayerConfiguration) -> MyPlayerController {
        configuration = config
        return self
    }
    
    func execute(_ completion: ((MyPlayerController) -> Void)?) -> MyPlayerController {
        MyPlayerManager.shared.cacheController(self)
        
        let asset = AVURLAsset(url: url, options: nil)
        let tracksKey = "tracks"
        
        asset.loadValuesAsynchronously(forKeys: [tracksKey]) { [weak self] in
            guard let `self` = self else {return}
            var error: NSError?
            let status = asset.statusOfValue(forKey: tracksKey, error: &error)
            switch status {
            case .unknown:
                break
                
            case .loading:
                break
                
            case .loaded:
                self.setPlayerItem(AVPlayerItem(asset: asset))
                
            case .failed:
                self.error = MyPlayerError.DidFailToLoadContent
                
            default: // Cancel
                self.error = MyPlayerError.DidCancelLoadContent
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else {return}
                completion?(self)
            }
        }
        
        return self
    }
    
    fileprivate func setPlayerItem(_ item: AVPlayerItem) {
        playerItem = item
        item.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: NSKeyValueObservingOptions.new, context: nil)
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else {return}
            self.playerView.player = AVPlayer(playerItem: item)
        }
    }
    
    internal override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status),
            playerItem!.status == AVPlayerItem.Status.readyToPlay,
            configuration?.shouldPlayAfterLoaded ?? false
        {
            playerView.player.play()
        }
        else if keyPath == #keyPath(MyPlayerController.cleanPlayerBag) {
            if cleanPlayerBag == nil {
                MyPlayerManager.shared.removeController(self)
            }
        }
    }
    
    deinit {
        print("\(toString()) DEALLOC")
        playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        removeObserver(self, forKeyPath: #keyPath(MyPlayerController.cleanPlayerBag))
    }
}

class MyPlayerConfiguration: NSObject {
    var shouldPlayAfterLoaded = false
    
    func shouldPlayAfterLoaded(_ shouldPlay: Bool) -> MyPlayerConfiguration {
        shouldPlayAfterLoaded = shouldPlay
        return self
    }
}

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

fileprivate class MyPlayerManager {
    static let shared = MyPlayerManager()
    var controllers = [String: MyPlayerController]()
    let controllerQueue = DispatchQueue.init(label: "com.myplayermanager.controller")
    func cacheController(_ controller: MyPlayerController) {
        controllerQueue.sync { [weak self] in
            guard let `self` = self else {return}
            self.controllers[controller._id] = controller
        }
    }
    
    func removeController(_ controller: MyPlayerController) {
        controllerQueue.sync { [weak self] in
            guard let `self` = self else {return}
            self.controllers.removeValue(forKey: controller._id)
        }
    }
}
