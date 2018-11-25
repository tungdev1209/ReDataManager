//
//  MyCoreDataOperation.swift
//  MyCoreDataOperation
//
//  Created by Tung Nguyen on 10/24/18.
//  Copyright © 2018 Tung Nguyen. All rights reserved.
//

import UIKit
import CoreData

enum MyCoreDataError: Error {
    case CreateEntityDescriptionFail
    case FetchObjectFail
    case SaveObjectFail
    case UpdateObjectFail
    case DeleteObjectFail
    case DeleteObjectsFail
    case InvalidStoreURL
    case ProtectStoreFail
    case LoadStoreFail
    case Unknown
}

enum MyCoreDataMode {
    case Main
    case Background
    case BackgroundScoped
    case Unknown
}

enum MyCoreDataStoreType {
    case SQLite
    case Binary
    case InMemory
    case Key
    case UUIDKey
    
    func stringValue() -> String {
        switch self {
        case .Binary:
            return NSBinaryStoreType
            
        case .InMemory:
            return NSInMemoryStoreType
            
        case .Key:
            return NSStoreTypeKey
            
        case .UUIDKey:
            return NSStoreUUIDKey
            
        default:
            return NSSQLiteStoreType
        }
    }
}

class MyCoreDataOperation {
    var predicate: NSPredicate?
    var sortDescriptors: [NSSortDescriptor]?
    var returnsObjectsAsFaults = false
    var propertiesToUpdate: [AnyHashable: Any]?
    var fetchLimit = -1
    var shouldRequestAsynchronously = true
    weak var delegateQueue: DispatchQueue?
    var operating: ((MyCoreDataOperation) -> Void)?
    private(set) var context: NSManagedObjectContext?
    private(set) var mode = MyCoreDataMode.Unknown
    
    fileprivate let _id = NSUUID.createBaseTime()
    
    convenience init(_ contextMode: MyCoreDataMode) {
        self.init()
        mode = contextMode
        context = getContext()
    }
    
    // MARK: - Private funcs
    private func getContext() -> NSManagedObjectContext? {
        var context: NSManagedObjectContext?
        MyCoreDataManager.shared.execute({ [weak self] in
            guard let `self` = self else {return}
            switch self.mode {
            case .Background:
                context = MyCoreDataStack.shared.backgroundManagedObjectContext(true)
                
            case .BackgroundScoped:
                context = MyCoreDataStack.shared.backgroundManagedObjectContext(false)
                
            default:
                context = MyCoreDataStack.shared.managedObjectContext()
            }
        }, asynchronously: false)
        return context
    }
    
    private func getFetchRequest<T: NSManagedObject>(_ entityClass: T.Type) -> NSFetchRequest<NSFetchRequestResult> {
        let fetch = entityClass.fetchRequest()
        fetch.predicate = predicate
        fetch.sortDescriptors = sortDescriptors
        fetch.returnsObjectsAsFaults = returnsObjectsAsFaults
        if fetchLimit != -1 {
            fetch.fetchLimit = fetchLimit
        }
        return fetch
    }
    
    private func getBatchUpdateRequest<T: NSManagedObject>(_ entityClass: T.Type) -> NSBatchUpdateRequest {
        let request = NSBatchUpdateRequest(entityName: String(describing: T.self))
        request.predicate = predicate
        request.propertiesToUpdate = propertiesToUpdate
        request.resultType = NSBatchUpdateRequestResultType.updatedObjectIDsResultType
        return request
    }
    
    private func getBatchDeleteRequest<T: NSManagedObject>(_ entityClass: T.Type) -> NSBatchDeleteRequest {
        let request = NSBatchDeleteRequest(fetchRequest: getFetchRequest(entityClass))
        request.resultType = NSBatchDeleteRequestResultType.resultTypeObjectIDs
        return request
    }
    
    private func finalCompletion(_ compl: (() -> Void)?) {
        var queue: DispatchQueue! = delegateQueue
        if queue == nil {
            queue = mode == .Main ? DispatchQueue.main : MyCoreDataManager.shared.completionQueue
        }
        queue.async {
            compl?()
        }
    }
    
    // MARK: - Public funcs
    class func startup(_ configuration: MyCoreDataOperationConfiguration, completion: ((MyCoreDataError?) -> Void)?) {
        let operation = MyCoreDataOperation()
        MyCoreDataManager.shared.cacheOperation(operation)
        MyCoreDataManager.shared.startup({
            var error: MyCoreDataError?
            let semaphore = DispatchSemaphore(value: 0)
            MyCoreDataStack.shared.loadPersistentContainer(configuration) { (coredataError) in
                error = coredataError
                MyCoreDataManager.shared.loadPersistentSuccess = error == nil
                semaphore.signal()
            }
            semaphore.wait()
            MyCoreDataManager.shared.removeOperation(operation)
            
            DispatchQueue.main.async {
                completion?(error)
            }
        })
    }
    
    class func cleanup() {
        let operation = MyCoreDataOperation()
        MyCoreDataManager.shared.cacheOperation(operation)
        MyCoreDataManager.shared.cleanup({
            MyCoreDataStack.shared.unload()
            MyCoreDataManager.shared.loadPersistentSuccess = false
            MyCoreDataManager.shared.removeOperation(operation)
        })
    }
    
    func shouldRequestAsynchronously(_ asyncRequest: Bool) -> MyCoreDataOperation {
        shouldRequestAsynchronously = asyncRequest
        return self
    }
    
    func delegateQueue(_ queue: DispatchQueue?) -> MyCoreDataOperation {
        delegateQueue = queue
        return self
    }
    
    func operating(_ op: ((MyCoreDataOperation) -> Void)?) -> MyCoreDataOperation {
        operating = op
        return self
    }
    
    func predicate(_ pre: NSPredicate?) -> MyCoreDataOperation {
        predicate = pre
        return self
    }
    
    func sortDescriptors(_ sorts: [NSSortDescriptor]?) -> MyCoreDataOperation {
        sortDescriptors = sorts
        return self
    }
    
    func returnsObjectsAsFaults(_ re: Bool) -> MyCoreDataOperation {
        returnsObjectsAsFaults = re
        return self
    }
    
    func fetchLimit(_ limit: Int) -> MyCoreDataOperation {
        fetchLimit = limit
        return self
    }
    
    func convertObject<T: NSManagedObject>(_ object: T, toMain: Bool = false) -> T? {
        var aContext: NSManagedObjectContext?
        if toMain {
            aContext = MyCoreDataStack.shared.managedObjectContext()
        }
        else {
            aContext = context
        }
        var obj = aContext?.object(with: object.objectID) as? T
        if let _obj = obj, _obj.isFault {
            do {
                obj = try aContext?.existingObject(with: object.objectID) as? T
            } catch {
                print("CoreData - Failed to convert object \(object) - \(error)")
            }
        }
        return obj
    }
    
    func createObject<T: NSManagedObject>(_ entityClass: T.Type) -> T? {
        if let _ = context {
            return T(context: context!)
        }
        return nil
    }
    
    func createObjectIfNeeded<T: NSManagedObject>(_ object: T?) -> T? {
        if let obj = object {
            return convertObject(obj)
        }
        return createObject(T.self)
    }
    
    // MARK: Save
    func executeSave(_ completion: ((MyCoreDataOperation, MyCoreDataError?) -> Void)?) {
        guard let _ = context else {return}
        
        // cache this operation
        MyCoreDataManager.shared.cacheOperation(self)
        
        var requestSemaphore: DispatchSemaphore?
        if !shouldRequestAsynchronously {
            requestSemaphore = DispatchSemaphore(value: 0)
        }
        
        var myError: MyCoreDataError?
        
        MyCoreDataManager.shared.execute({ [weak self] in
            print(MyCoreDataManager.shared.operations)
            guard let `self` = self else {return}
            
            self.context?.performAndWait { [weak self] in
                guard let `self` = self else {return}
                
                self.operating?(self)
                
                guard let _ = self.context, self.context!.hasChanges else {return}
                do {
                    try self.context?.save()
                }
                catch {
                    print("Coredata - Failed to save - error: \(error)")
                    myError = MyCoreDataError.SaveObjectFail
                }
            }
            requestSemaphore?.signal()
            
            // for async request
            if self.shouldRequestAsynchronously {
                self.finalCompletion { [weak self] in
                    guard let `self` = self else {return}
                    MyCoreDataManager.shared.removeOperation(self)
                    completion?(self, myError)
                }
            }
        }, flags: .barrier)
        
        requestSemaphore?.wait()
        
        // for sync request
        if !shouldRequestAsynchronously {
            MyCoreDataManager.shared.removeOperation(self)
            completion?(self, myError)
        }
    }
    
    // MARK: Fetch
    func executeFetch<T: NSManagedObject>(_ entityClass: T.Type, completion: ((MyCoreDataOperation, [T]?) -> Void)?) {
        guard let _ = context else {return}
        
        // cache this operation
        MyCoreDataManager.shared.cacheOperation(self)
        
        var requestSemaphore: DispatchSemaphore?
        if !shouldRequestAsynchronously {
            requestSemaphore = DispatchSemaphore(value: 0)
        }
        
        var result: [T]?
        
        MyCoreDataManager.shared.execute({ [weak self] in
            guard let `self` = self else {return}
            
            var semaphore: DispatchSemaphore?
            if let _ = self.context {
                semaphore = DispatchSemaphore(value: 0)
            }
            
            self.context?.perform { [weak self] in
                guard let `self` = self else {return}
                
                self.operating?(self)
                
                do {
                    try self.context?.execute(NSAsynchronousFetchRequest.init(fetchRequest: self.getFetchRequest(entityClass)) { (fetchResult) in
                        result = fetchResult.finalResult as? [T]
                        semaphore?.signal()
                    })
                }
                catch {
                    print("Failed to fetch \(String(describing: T.self)) - error: \(error)")
                    semaphore?.signal()
                }
            }
            
            semaphore?.wait()
            requestSemaphore?.signal()
            
            // for async request
            if self.shouldRequestAsynchronously {
                self.finalCompletion { [weak self] in
                    guard let `self` = self else {return}
                    MyCoreDataManager.shared.removeOperation(self)
                    completion?(self, result)
                }
            }
        })
        
        // for sync request
        requestSemaphore?.wait()
        if !shouldRequestAsynchronously {
            MyCoreDataManager.shared.removeOperation(self)
            completion?(self, result)
        }
    }
    
    // MARK: Batch Update
    func executeBatchUpdate<T: NSManagedObject>(_ propertiesToUpdate: [AnyHashable: Any]?, entityClass: T.Type, completion: ((MyCoreDataOperation, MyCoreDataError?) -> Void)?) {
        guard let _ = context else {return}
        
        // cache this operation
        MyCoreDataManager.shared.cacheOperation(self)
        
        var requestSemaphore: DispatchSemaphore?
        if !shouldRequestAsynchronously {
            requestSemaphore = DispatchSemaphore(value: 0)
        }
        
        var myError: MyCoreDataError?
        
        MyCoreDataManager.shared.execute({ [weak self] in
            guard let `self` = self else {return}
            
            // prepare attributes
            self.propertiesToUpdate = propertiesToUpdate
            
            self.context?.performAndWait { [weak self] in
                guard let `self` = self else {return}
                
                self.operating?(self)
                
                do {
                    let result = try self.context?.execute(self.getBatchUpdateRequest(entityClass)) as? NSBatchUpdateResult
                    print("CoreData - Did batch update: \(String(describing: result))")
                    MyCoreDataStack.shared.mergeChanges(result?.result as? [NSManagedObjectID], context: self.context)
                }
                catch {
                    print("Failed to batch update \(String(describing: T.self)) - error: \(error)")
                    myError = MyCoreDataError.UpdateObjectFail
                }
            }
            requestSemaphore?.signal()
            
            // for async request
            if self.shouldRequestAsynchronously {
                self.finalCompletion { [weak self] in
                    guard let `self` = self else {return}
                    MyCoreDataManager.shared.removeOperation(self)
                    completion?(self, myError)
                }
            }
        }, flags: .barrier)
        
        // for sync request
        requestSemaphore?.wait()
        if !shouldRequestAsynchronously {
            MyCoreDataManager.shared.removeOperation(self)
            completion?(self, myError)
        }
    }
    
    // MARK: Delete
    func executeDelete(_ object: NSManagedObject, save: Bool = false, completion: ((MyCoreDataOperation, MyCoreDataError?) -> Void)? = nil) {
        guard let _ = context else {return}
        
        context?.delete(object)
        if save {
            executeSave({ (operation, error) in
                var myError = error
                if let _ = myError {
                    myError = MyCoreDataError.DeleteObjectFail
                }
                completion?(operation, myError)
            })
        }
        else {
            completion?(self, nil)
        }
    }
    
    // MARK: Batch Delete
    func executeBatchDelete<T: NSManagedObject>(_ entityClass: T.Type, completion: ((MyCoreDataOperation, MyCoreDataError?) -> Void)?) {
        guard let _ = context else {return}
        
        // cache this operation
        MyCoreDataManager.shared.cacheOperation(self)
        
        var requestSemaphore: DispatchSemaphore?
        if !shouldRequestAsynchronously {
            requestSemaphore = DispatchSemaphore(value: 0)
        }
        
        var myError: MyCoreDataError?
        
        MyCoreDataManager.shared.execute({ [weak self] in
            guard let `self` = self else {return}
            
            self.context?.performAndWait { [weak self] in
                guard let `self` = self else {return}
                
                self.operating?(self)
                
                do {
                    let result = try self.context?.execute(self.getBatchDeleteRequest(entityClass)) as? NSBatchDeleteResult
                    print("CoreData - Did batch delete: \(String(describing: result))")
                    MyCoreDataStack.shared.mergeChanges(result?.result as? [NSManagedObjectID], context: self.context)
                }
                catch {
                    print("Failed to batch delete \(String(describing: T.self)) - error: \(error)")
                    myError = MyCoreDataError.DeleteObjectsFail
                }
            }
            requestSemaphore?.signal()
            
            // for async request
            if self.shouldRequestAsynchronously {
                self.finalCompletion { [weak self] in
                    guard let `self` = self else {return}
                    MyCoreDataManager.shared.removeOperation(self)
                    completion?(self, myError)
                }
            }
            }, flags: .barrier)
        
        // for sync request
        requestSemaphore?.wait()
        if !shouldRequestAsynchronously {
            MyCoreDataManager.shared.removeOperation(self)
            completion?(self, myError)
        }
    }
    
    deinit {
        print("=== CoreData Operation DEALLOC ===")
    }
}

fileprivate class MyCoreDataManager {
    static let shared = MyCoreDataManager()
    var loadPersistentSuccess = false
    var operations = [String: MyCoreDataOperation]()
    let operationQueue = DispatchQueue.init(label: "com.mycoredata.operation")
    let executionQueue = DispatchQueue.init(label: "com.mycoredata.execution", attributes: .concurrent)
    let completionQueue = DispatchQueue.init(label: "com.mycoredata.completion", attributes: .concurrent)
    
    func startup(_ starting: (() -> Void)?) {
        executionQueue.async(flags: .barrier) {
            starting?()
        }
    }
    
    func cleanup(_ cleaning: (() -> Void)?) {
        executionQueue.async(flags: .barrier) {
            cleaning?()
        }
    }
    
    func cacheOperation(_ operation: MyCoreDataOperation) {
        operationQueue.sync { [weak self] in
            guard let `self` = self else {return}
            self.operations[operation._id] = operation
        }
    }
    
    func removeOperation(_ operation: MyCoreDataOperation) {
        operationQueue.sync { [weak self] in
            guard let `self` = self else {return}
            self.operations.removeValue(forKey: operation._id)
        }
    }
    
    func isExecutable() -> Bool {
        if !loadPersistentSuccess {
            print("Coredata ERROR => Failed to load Model")
        }
        return loadPersistentSuccess
    }
    
    func execute(_ executing: (() -> Void)?, asynchronously: Bool = true) {
        guard isExecutable() else {return}
        var semaphore: DispatchSemaphore?
        if !asynchronously {
            semaphore = DispatchSemaphore(value: 0)
        }
        executionQueue.async {
            executing?()
            semaphore?.signal()
        }
        if !asynchronously {
            semaphore?.wait()
        }
    }
    
    func execute(_ executing: (() -> Void)?, flags: DispatchWorkItemFlags, asynchronously: Bool = true) {
        guard isExecutable() else {return}
        var semaphore: DispatchSemaphore?
        if !asynchronously {
            semaphore = DispatchSemaphore(value: 0)
        }
        executionQueue.async(flags: flags) {
            executing?()
            semaphore?.signal()
        }
        if !asynchronously {
            semaphore?.wait()
        }
    }
}

fileprivate class MyCoreDataStack {
    
    static let shared = MyCoreDataStack()
    
    // MARK: - Core Data stack
    private var persistentContainer: NSPersistentContainer!
    private var backgroundContext: NSManagedObjectContext!
    private let contextsQueue = DispatchQueue.init(label: "com.mycoredata.stack.contexts")
    
    private var protectStoreBlock: (() -> Void)?
    
    lazy private var contexts: NSHashTable<NSManagedObjectContext> = {
        return NSHashTable<NSManagedObjectContext>(options: NSPointerFunctions.Options.weakMemory)
    }()
    
    func unload() {
        protectStoreBlock?()
        protectStoreBlock = nil
        backgroundContext = nil
        persistentContainer = nil
    }
    
    func loadPersistentContainer(_ configuration: MyCoreDataOperationConfiguration, completion: ((MyCoreDataError?) -> Void)?) {
        initializePersistentContainer(configuration) { [weak self] (error) in
            guard let `self` = self else {return}
            self.didInitializeContainer(error)
            completion?(error)
        }
    }
    
    private func initializePersistentContainer(_ configuration: MyCoreDataOperationConfiguration, completion: ((MyCoreDataError?) -> Void)?) {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        guard var appModelPathURL = applicationDocumentsDirectory(configuration.appsGroupName) else {
            completion?(MyCoreDataError.InvalidStoreURL)
            return
        }
        
        // Check store path
        if !configuration.modelPath.isEmpty {
            appModelPathURL.appendPathComponent(configuration.modelPath)
            if !FileManager.default.createDirectoryIfNeeded(appModelPathURL.path, attributes: nil) {
                completion?(MyCoreDataError.InvalidStoreURL)
                return
            }
        }
        
        // Check protection
        if configuration.protection {
            let storeEncPath = appModelPathURL.appendingPathComponent(configuration.modelName + "_enc.sqlite")
            let storeDecPath = appModelPathURL.appendingPathComponent(configuration.modelName + ".sqlite")
            if FileManager.default.fileExists(atPath: storeEncPath.path),
                !FileManager.default.decryptAESFileAt(storeEncPath.path, newPath: storeDecPath.path, key: configuration.protectionAESKey.key, iv: configuration.protectionAESKey.iv) {
                completion?(MyCoreDataError.ProtectStoreFail)
                return
            }
            protectStoreBlock = {
                if FileManager.default.fileExists(atPath: storeDecPath.path),
                    !FileManager.default.encryptAESFileAt(storeDecPath.path, newPath: storeEncPath.path, key: configuration.protectionAESKey.key, iv: configuration.protectionAESKey.iv) {
                    print("Could not Encrypt store, might be leak sensitive information")
                }
            }
        }
        
        appModelPathURL.appendPathComponent(configuration.modelName + ".sqlite")
        
        let description = NSPersistentStoreDescription(url: appModelPathURL)
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        description.shouldAddStoreAsynchronously = configuration.shouldLoadStoreAsynchronously
        description.type = configuration.storeType.stringValue()
        
        persistentContainer = NSPersistentContainer(name: configuration.modelName)
        persistentContainer.persistentStoreDescriptions = [description]
        persistentContainer.loadPersistentStores(completionHandler: { (storeDescription, error) in
            print("CoreData - Did load model at path: \(appModelPathURL.path)")
            var err: MyCoreDataError?
            if let _ = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
//                fatalError("Unresolved error \(error), \(error.userInfo)")
                err = MyCoreDataError.LoadStoreFail
            }
            completion?(err)
        })
    }
    
    private func didInitializeContainer(_ error: MyCoreDataError?) {
        guard error == nil else {return}
        
        contextsQueue.sync { [weak self] in
            guard let `self` = self else {return}
            self.contexts.removeAllObjects()
        }
        
        backgroundContext = persistentContainer.newBackgroundContext()
        
        applyContextAttributes(managedObjectContext())
        applyContextAttributes(backgroundContext)
    }
    
    private func applyContextAttributes(_ context: NSManagedObjectContext, keepContext: Bool = true) {
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
        if keepContext {
            contextsQueue.sync { [weak self] in
                guard let `self` = self else {return}
                self.contexts.add(context)
            }
        }
    }
    
    func applicationDocumentsDirectory(_ groupName: String = "") -> URL? {
        if groupName.isEmpty {
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupName)
    }
    
    func managedObjectContext() -> NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func backgroundManagedObjectContext(_ keepAlive: Bool = false) -> NSManagedObjectContext {
        if keepAlive {
            return backgroundContext
        }
        else {
            let newContext = persistentContainer.newBackgroundContext()
            applyContextAttributes(newContext)
            return newContext
        }
    }
    
    func mergeChanges(_ objectIDs: [NSManagedObjectID]?, context: NSManagedObjectContext?) {
        guard let objIDs = objectIDs, let _ = context else {return}
        contextsQueue.sync { [weak self] in
            guard let `self` = self else {return}
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSUpdatedObjectsKey: objIDs], into: self.contexts.allObjects)
        }
    }
    
    func managedObjectModel() -> NSManagedObjectModel {
        return persistentContainer.managedObjectModel
    }
    
    func persistentStoreCoordinator() -> NSPersistentStoreCoordinator {
        return persistentContainer.persistentStoreCoordinator
    }
}

class MyCoreDataOperationConfiguration {
    var modelName = ""
    var modelPath = ""
    var appsGroupName = ""
    var storeType = MyCoreDataStoreType.SQLite
    var shouldLoadStoreAsynchronously = true
    var protection = false
    var protectionAESKey: (key: [UInt8], iv: [UInt8]) =
        (key: [0x70, 0x65, 0xD1, 0x2C, 0xBB, 0xB3, 0xAE, 0x89, 0x84, 0x9B, 0x00, 0x6F, 0xE0, 0x12, 0x5A, 0xA0, 0x83, 0x10, 0x83, 0x1D, 0x05, 0xE2, 0xB0, 0xE6, 0x5C, 0x5C, 0x5C, 0xC9, 0xC7, 0x05, 0x55, 0xE1],
         iv: [0x08, 0x10, 0x53, 0xCC, 0x78, 0xCC, 0x6D, 0x31, 0xAF, 0x83, 0xAD, 0x6F, 0x23, 0xB9, 0x36, 0x1A])
    
    // pass: FDR#e-Tr@_n-B-]k?}i6-y{GSeRr6Tf
    // salt=6CCBF501E3B03835
    // key=7065D12CBBB3AE89849B006FE0125AA08310831D05E2B0E65C5C5CC9C70555E1
    // iv =081053CC78CC6D31AF83AD6F23B9361A
    
    convenience init(_ modelName: String) {
        self.init()
        self.modelName = modelName
    }
    
    func modelPath(_ mPath: String) -> MyCoreDataOperationConfiguration {
        modelPath = mPath
        return self
    }
    
    func appsGroupName(_ agName: String) -> MyCoreDataOperationConfiguration {
        appsGroupName = agName
        return self
    }
    
    func storeType(_ type: MyCoreDataStoreType) -> MyCoreDataOperationConfiguration {
        storeType = type
        return self
    }
    
    func shouldLoadStoreAsynchronously(_ loadAsync: Bool) -> MyCoreDataOperationConfiguration {
        shouldLoadStoreAsynchronously = loadAsync
        return self
    }
    
    func protection(_ pro: Bool) -> MyCoreDataOperationConfiguration {
        protection = pro
        return self
    }
    
    func protectionAES128Key(_ key: (key: [UInt8], iv: [UInt8])) -> MyCoreDataOperationConfiguration {
        protectionAESKey = key
        return self
    }
}
