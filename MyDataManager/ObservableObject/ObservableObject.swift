//
//  ObservableObject.swift
//  ObservableSwift
//
//  Created by Tung Nguyen on 11/8/18.
//  Copyright © 2018 Tung Nguyen. All rights reserved.
//

import UIKit

typealias SubcribeBlock = ((String, Any?) -> Void)

let kCleanBagDealloc = "CleanBag_Dealloc"
let kCleanBagObjectId = "CleanBag_ObjectId"

class CleanBag: NSObject {
    fileprivate let bagId = NSUUID.createBaseTime()
    fileprivate let subcribers = NSHashTable<AnyObject>(options: NSPointerFunctions.Options.weakMemory)
    fileprivate func registerSubcriberObject(_ subcriber: Subcriber) {
        subcribers.add(subcriber)
    }
    
    fileprivate func removeAllSubcribers() {
        subcribers.removeAllObjects()
    }
    
    deinit {
        for sub in subcribers.allObjects as! [Subcriber] {
            sub.bag = nil
        }
    }
}

class Subcriber: NSObject {
    var subBlock: SubcribeBlock?
    
    @objc dynamic fileprivate weak var bag: CleanBag?
    
    fileprivate let subcriberId = NSUUID.createBaseTime()
    fileprivate weak var observableObj: ObservableObject?
    
    func cleanupBy(_ b: CleanBag) {
        guard b.bagId != bag?.bagId else {return}
        if let _ = bag {
            removeObservingBag()
        }
        bag = b
        b.registerSubcriberObject(self)
        addObservingBag()
    }
    
    fileprivate func addObservingBag() {
        addObserver(self, forKeyPath: #keyPath(Subcriber.bag), options: NSKeyValueObservingOptions.new, context: nil)
    }
    
    fileprivate func removeObservingBag() {
        removeObserver(self, forKeyPath: #keyPath(Subcriber.bag), context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(Subcriber.bag) {
            removeObservingBag()
            observableObj?.removeSubcriberWithId(subcriberId)
        }
    }
}

class ObservableObject: NSObject {
    fileprivate var subcriberIds = [String]()
    fileprivate var selectorSubcribers = [String: [String]]()
    fileprivate var subcriberById = [String: Subcriber]()
    fileprivate let observationQueue = DispatchQueue(label: "com.observable.observation")
    fileprivate let executionQueue = DispatchQueue(label: "com.observable.execution")
    fileprivate var obsAdded = false
    fileprivate let objectID = NSUUID.createBaseTime()
    
    @objc dynamic fileprivate var syncupObject: ObservableObject?
    
    func syncupWithObject(_ object: ObservableObject) -> ObservableObject {
        guard syncupObject?.objectID != objectID else {return self}
        executionQueue.sync { [weak self] in
            guard let `self` = self else {return}
            if let _ = self.syncupObject {
                self.removeSyncupObservingProperties()
            }
            self.syncupObject = object
            self.addSyncupObservingProperties()
        }
        return self
    }
    
    func removeSyncupObject() -> ObservableObject {
        if let _ = syncupObject {
            removeSyncupObservingProperties()
            syncupObject = nil
        }
        return self
    }
    
    func subcribe(_ block: SubcribeBlock?) -> Subcriber {
        var subcriber: Subcriber!
        executionQueue.sync { [weak self] in
            guard let `self` = self else {return}
            subcriber = self.addSubcriberWithBlock(block)
            subcriberIds.append(subcriber.subcriberId)
        }
        return subcriber
    }
    
    func subcribeKeySelector(_ keyPath: String, binding: SubcribeBlock?) -> Subcriber {
        var subcriber: Subcriber!
        executionQueue.sync { [weak self] in
            guard let `self` = self else {return}
            subcriber = self.addSubcriberWithBlock(binding)
            self.addSubcriber(subcriber, keyPath: keyPath)
        }
        return subcriber
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let kPath = keyPath else {return}
        
        if let obj = object as? ObservableObject, obj.objectID == syncupObject?.objectID {
            syncupValueForKeyPath(kPath)
            return
        }
        
        executionQueue.sync { [weak self] in
            guard let `self` = self else {return}
            guard let propertySelectorSubcriberIds = selectorSubcribers[kPath] else {return}
            for subcriberId in propertySelectorSubcriberIds {
                if let sub = self.subcriberById[subcriberId] {
                    sub.subBlock?(kPath, value(forKey: kPath))
                }
            }
            
            for subcriberId in subcriberIds {
                if let sub = self.subcriberById[subcriberId] {
                    sub.subBlock?(kPath, value(forKey: kPath))
                }
            }
        }
    }
    
    fileprivate func addSubcriberWithBlock(_ subBlock: SubcribeBlock?) -> Subcriber {
        addObservingProperties()
        
        let subcriber = Subcriber()
        subcriber.subBlock = subBlock
        subcriber.observableObj = self
        
        subcriberById[subcriber.subcriberId] = subcriber
        return subcriber
    }
    
    fileprivate func addSubcriber(_ subcriber: Subcriber, keyPath: String) {
        var subs = selectorSubcribers[keyPath]
        if subs == nil {
            subs = []
        }
        subs!.append(subcriber.subcriberId)
        selectorSubcribers[keyPath] = subs
    }
    
    fileprivate func removeSubcriberWithId(_ subcriberId: String) {
        subcriberIds = subcriberIds.filter({ $0 != subcriberId })
        subcriberById.removeValue(forKey: subcriberId)
        for keyPath in selectorSubcribers.keys {
            var selectorSubcriberIds = selectorSubcribers[keyPath]
            selectorSubcriberIds = selectorSubcriberIds?.filter({ $0 != subcriberId })
            selectorSubcribers[keyPath] = selectorSubcriberIds
        }
    }
    
    fileprivate func syncupValues() {
        guard let syncupObj = syncupObject else {return}
        for case let (label, _) in Mirror.init(reflecting: syncupObj).children {
            guard let keyPath = label else {continue}
            syncupValueForKeyPath(keyPath)
        }
    }
    
    fileprivate func syncupValueForKeyPath(_ keyPath: String) {
        let value = syncupObject?.value(forKey: keyPath)
        setValue(value, forKey: keyPath)
    }
    
    // MARK: add/remove funcs
    fileprivate func addObservingProperties() {
        observationQueue.sync { [weak self] in
            guard let `self` = self else {return}
            guard !self.obsAdded else {return}
            self.obsAdded = true
            self.addObservingPropertiesForObject(self)
        }
    }
    
    fileprivate func addSyncupObservingProperties() {
        observationQueue.sync { [weak self] in
            guard let `self` = self, let obj = self.syncupObject else {return}
            self.addObservingPropertiesForObject(obj)
        }
    }
    
    fileprivate func addObservingPropertiesForObject(_ object: NSObject) {
        for case let (label, _) in Mirror.init(reflecting: object).children {
            guard let keyPath = label else {continue}
            object.addObserver(self, forKeyPath: keyPath, options: NSKeyValueObservingOptions.new, context: nil)
        }
    }
    
    fileprivate func removeObservingProperties() {
        observationQueue.sync { [weak self] in
            guard let `self` = self else {return}
            guard self.obsAdded else {return}
            self.obsAdded = false
            self.removeObservingPropertiesForObject(self)
        }
    }
    
    fileprivate func removeSyncupObservingProperties() {
        observationQueue.sync { [weak self] in
            guard let `self` = self, let obj = self.syncupObject else {return}
            self.removeObservingPropertiesForObject(obj)
        }
    }
    
    fileprivate func removeObservingPropertiesForObject(_ object: NSObject) {
        for case let (label, _) in Mirror.init(reflecting: object).children {
            guard let keyPath = label else {continue}
            object.removeObserver(self, forKeyPath: keyPath)
        }
    }
    
    fileprivate func removeSubcribers() {
        executionQueue.sync { [weak self] in
            guard let `self` = self else {return}
            self.subcriberIds.removeAll()
            self.selectorSubcribers.removeAll()
            self.subcriberById.removeAll()
        }
    }
    
    deinit {
        removeObservingProperties()
        removeSyncupObservingProperties()
        removeSubcribers()
    }
}
