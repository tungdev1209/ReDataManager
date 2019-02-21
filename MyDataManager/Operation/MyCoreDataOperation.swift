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
    case ReadStoreFail
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
    
    private func getFetchRequest(_ entityName: String) -> NSFetchRequest<NSFetchRequestResult> {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
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
        let request = NSBatchDeleteRequest(fetchRequest: getFetchRequest(String(describing: T.self)))
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
        
        var error: MyCoreDataError?
        let isAsyncStartup = configuration.shouldLoadStoreAsynchronously
        MyCoreDataManager.shared.startup({
            var semaphore: DispatchSemaphore?
            if isAsyncStartup {
                semaphore = DispatchSemaphore(value: 0)
            }
            MyCoreDataStack.shared.loadPersistentContainer(configuration) { (coredataError) in
                error = coredataError
                MyCoreDataManager.shared.loadPersistentSuccess = error == nil
                semaphore?.signal()
            }
            semaphore?.wait()
            
            if isAsyncStartup {
                MyCoreDataManager.shared.removeOperation(operation)
                DispatchQueue.main.async {
                    completion?(error)
                }
            }
        }, asynchronously: isAsyncStartup)
        
        if !isAsyncStartup {
            MyCoreDataManager.shared.removeOperation(operation)
            completion?(error)
        }
    }
    
    class func unload() {
        MyCoreDataManager.shared.cleanup({
            MyCoreDataStack.shared.unload()
            MyCoreDataManager.shared.loadPersistentSuccess = false
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
        
        var myError: MyCoreDataError?
        
        MyCoreDataManager.shared.execute({ [weak self] in
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
            
            // for async request
            if self.shouldRequestAsynchronously {
                self.finalCompletion { [weak self] in
                    guard let `self` = self else {return}
                    MyCoreDataManager.shared.removeOperation(self)
                    completion?(self, myError)
                }
            }
        }, flags: .barrier, asynchronously: shouldRequestAsynchronously)
        
        // for sync request
        if !shouldRequestAsynchronously {
            MyCoreDataManager.shared.removeOperation(self)
            completion?(self, myError)
        }
    }
    
    // MARK: Fetch
    func executeFetch(_ entityName: String, completion: ((MyCoreDataOperation, [NSManagedObject]) -> Void)?) {
        guard let _ = context else {return}
        
        // cache this operation
        MyCoreDataManager.shared.cacheOperation(self)
        
        var result = [NSManagedObject]()
        
        MyCoreDataManager.shared.execute({ [weak self] in
            guard let `self` = self else {return}
            
            let execution = { [weak self] in
                guard let `self` = self else {return}
                
                do {
                    result = try self.context?.fetch(self.getFetchRequest(entityName)) as? [NSManagedObject] ?? []
                }
                catch {
                    print("Failed to fetch \(entityName) - error: \(error)")
                }
            }
            
            self.context?.performAndWait { [weak self] in
                guard let `self` = self else {return}
                
                // execute operating closure
                self.operating?(self)
                
                // execute fetch request
                execution()
            }
            
            // async completion
            if self.shouldRequestAsynchronously {
                self.finalCompletion { [weak self] in
                    guard let `self` = self else {return}
                    MyCoreDataManager.shared.removeOperation(self)
                    completion?(self, result)
                }
            }
        }, asynchronously: shouldRequestAsynchronously)
        
        // sync completion
        if !shouldRequestAsynchronously {
            MyCoreDataManager.shared.removeOperation(self)
            completion?(self, result)
        }
    }
    
    func executeFetch<T: NSManagedObject>(_ entityClass: T.Type, completion: ((MyCoreDataOperation, [T]) -> Void)?) {
        executeFetch(String(describing: T.self)) { (op, objects) in
            completion?(op, objects as? [T] ?? [])
        }
    }
    
    // MARK: Batch Update
    func executeBatchUpdate<T: NSManagedObject>(_ propertiesToUpdate: [AnyHashable: Any]?, entityClass: T.Type, completion: ((MyCoreDataOperation, MyCoreDataError?) -> Void)?) {
        guard let _ = context else {return}
        
        // cache this operation
        MyCoreDataManager.shared.cacheOperation(self)
        
        var myError: MyCoreDataError?
        
        MyCoreDataManager.shared.execute({ [weak self] in
            guard let `self` = self else {return}
            
            // prepare attributes
            self.propertiesToUpdate = propertiesToUpdate
            
            let execution = { [weak self] in
                guard let `self` = self else {return}
                
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
            
            self.context?.performAndWait { [weak self] in
                guard let `self` = self else {return}
                
                self.operating?(self)
                
                execution()
            }
            
            // for async request
            if self.shouldRequestAsynchronously {
                self.finalCompletion { [weak self] in
                    guard let `self` = self else {return}
                    MyCoreDataManager.shared.removeOperation(self)
                    completion?(self, myError)
                }
            }
        }, flags: .barrier, asynchronously: shouldRequestAsynchronously)
        
        // for sync request
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
        
        var myError: MyCoreDataError?
        
        MyCoreDataManager.shared.execute({ [weak self] in
            guard let `self` = self else {return}
            
            let execution = { [weak self] in
                guard let `self` = self else {return}
                
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
            
            self.context?.performAndWait { [weak self] in
                guard let `self` = self else {return}
                
                self.operating?(self)
                
                execution()
            }
            
            // for async request
            if self.shouldRequestAsynchronously {
                self.finalCompletion { [weak self] in
                    guard let `self` = self else {return}
                    MyCoreDataManager.shared.removeOperation(self)
                    completion?(self, myError)
                }
            }
        }, flags: .barrier, asynchronously: shouldRequestAsynchronously)
        
        // for sync request
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
    
    func startup(_ starting: (() -> Void)?, asynchronously: Bool = true) {
        if asynchronously {
            executionQueue.async(flags: .barrier) {
                starting?()
            }
        }
        else {
            executionQueue.sync(flags: .barrier) {
                starting?()
            }
        }
    }
    
    func cleanup(_ cleaning: (() -> Void)?) {
        executionQueue.sync(flags: .barrier) {
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
        let execution = { [weak self] in
            guard let `self` = self else {return}
            guard self.isExecutable() else {return}
            
            executing?()
        }
        if asynchronously {
            executionQueue.async {
                execution()
            }
        }
        else {
            executionQueue.sync {
                execution()
            }
        }
    }
    
    func execute(_ executing: (() -> Void)?, flags: DispatchWorkItemFlags, asynchronously: Bool = true) {
        let execution = { [weak self] in
            guard let `self` = self else {return}
            guard self.isExecutable() else {return}
            executing?()
        }
        
        if asynchronously {
            executionQueue.async(flags: flags) {
                execution()
            }
        }
        else {
            executionQueue.sync(flags: flags) {
                execution()
            }
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
    private var unloadStoreBlock: (() -> Void)?
    
    private let coredataFileManager = FileManager()
    
    lazy private var contexts: NSHashTable<NSManagedObjectContext> = {
        return NSHashTable<NSManagedObjectContext>(options: NSPointerFunctions.Options.weakMemory)
    }()
    
    func unload() {
        contextsQueue.sync { [weak self] in
            guard let `self` = self else {return}
            self.contexts.allObjects.forEach({ (context) in
                context.automaticallyMergesChangesFromParent = false
            })
        }
        unloadStoreBlock?()
        unloadStoreBlock = nil
        protectStoreBlock?()
        protectStoreBlock = nil
        persistentContainer = nil
        backgroundContext = nil
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
            if !coredataFileManager.createDirectoryIfNeeded(appModelPathURL.path, attributes: nil) {
                completion?(MyCoreDataError.InvalidStoreURL)
                return
            }
        }
        
        // Check protection
        let storeEncPath = appModelPathURL.appendingPathComponent(configuration.modelName + "_enc.sqlite")
        let storeDecPath = appModelPathURL.appendingPathComponent(configuration.modelName + ".sqlite")
        
        if coredataFileManager.fileExists(atPath: storeEncPath.path) {
            let decryptStatus = coredataFileManager.decryptAESFileAt(storeEncPath.path, newPath: storeDecPath.path, key: configuration.protectionAESKey.key, iv: configuration.protectionAESKey.iv)
            if !decryptStatus || (decryptStatus && !storeEncPath.path.asFilePath(coredataFileManager).remove()) {
                completion?(MyCoreDataError.ReadStoreFail)
                return
            }
        }
        
        if configuration.protection {
            let subFileSHM = appModelPathURL.appendingPathComponent(configuration.modelName + ".sqlite-shm")
            let subFileWAL = appModelPathURL.appendingPathComponent(configuration.modelName + ".sqlite-wal")
            protectStoreBlock = { [weak self] in
                guard let `self` = self else {return}
                if self.coredataFileManager.fileExists(atPath: storeDecPath.path) {
                    if self.coredataFileManager.encryptAESFileAt(storeDecPath.path, newPath: storeEncPath.path, key: configuration.protectionAESKey.key, iv: configuration.protectionAESKey.iv) {
                        _ = storeDecPath.path.asFilePath(self.coredataFileManager).remove()
                        _ = subFileSHM.path.asFilePath(self.coredataFileManager).remove()
                        _ = subFileWAL.path.asFilePath(self.coredataFileManager).remove()
                    }
                    else {
                        print("Could not Encrypt store, might be leak the sensitive information")
                    }
                }
            }
        }
        
        var description: NSPersistentStoreDescription!
        if configuration.storeType == .SQLite {
            appModelPathURL.appendPathComponent(configuration.modelName + ".sqlite")
            description = NSPersistentStoreDescription(url: appModelPathURL)
        }
        else {
            description = NSPersistentStoreDescription()
        }
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        description.shouldAddStoreAsynchronously = configuration.shouldLoadStoreAsynchronously
        description.type = configuration.storeType.stringValue()
        
        // initilize persistent container
        if let momodel = configuration.managedObjectModel {
            persistentContainer = NSPersistentContainer(name: configuration.modelName, managedObjectModel: momodel)
        }
        else {
            persistentContainer = NSPersistentContainer(name: configuration.modelName)
        }
        persistentContainer.persistentStoreDescriptions = [description]
        
        // loading
        var err: MyCoreDataError?
        persistentContainer.loadPersistentStores(completionHandler: { (storeDescription, error) in
            print("CoreData - Did load model at path: \(String(describing: storeDescription.url?.path)), type: \(storeDescription.type)")
            
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
            
            if configuration.shouldLoadStoreAsynchronously {
                completion?(err)
            }
        })
        
        unloadStoreBlock = { [weak self] in
            guard let `self` = self else {return}
            let stores = self.persistentContainer.persistentStoreCoordinator.persistentStores
            for store in stores {
                try? self.persistentContainer.persistentStoreCoordinator.remove(store)
            }
        }
        
        if !configuration.shouldLoadStoreAsynchronously {
            completion?(err)
        }
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
            return coredataFileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        }
        return coredataFileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName)
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
    var managedObjectModel: NSManagedObjectModel?
    var appsGroupName = ""
    var storeType = MyCoreDataStoreType.SQLite
    var shouldLoadStoreAsynchronously = true
    var protection = false
    var protectionAESKey: (key: [UInt8], iv: [UInt8]) = (key: [], iv: [])
    
    convenience init(_ modelName: String) {
        self.init()
        self.modelName = modelName
    }
    
    func modelPath(_ mPath: String) -> MyCoreDataOperationConfiguration {
        modelPath = mPath
        return self
    }
    
    func managedObjectModel(_ momodel: NSManagedObjectModel) -> MyCoreDataOperationConfiguration {
        managedObjectModel = momodel
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
    
    func protectionAESKey(_ key: (key: [UInt8], iv: [UInt8])) -> MyCoreDataOperationConfiguration {
        protectionAESKey = key
        return self
    }
}
