//
//  MyCoreDataOperation.swift
//  ReDataManager
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
    case InvalidStoreURL
    case LoadStoreFail
    case Unknown
}

enum MyCoreDataMode {
    case Main
    case Background
    case BackgroundScoped
    case Unknown
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
    private(set) var context: NSManagedObjectContext!
    private(set) var mode = MyCoreDataMode.Unknown
    
    fileprivate var _id: String = ""
    
    convenience init(_ contextMode: MyCoreDataMode) {
        self.init()
        mode = contextMode
        context = getContext()
    }
    
    // MARK: - Private funcs
    private func getContext() -> NSManagedObjectContext {
        var context: NSManagedObjectContext!
        MyCoreDataManager.shared.executionQueue.sync {
            switch mode {
            case .Background:
                context = MyCoreDataStack.shared.backgroundManagedObjectContext(true)
                
            case .BackgroundScoped:
                context = MyCoreDataStack.shared.backgroundManagedObjectContext(false)
                
            default:
                context = MyCoreDataStack.shared.managedObjectContext()
            }
        }
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
    
    private func getUpdateRequest<T: NSManagedObject>(_ entityClass: T.Type) -> NSBatchUpdateRequest {
        let request = NSBatchUpdateRequest(entityName: String(describing: T.self))
        request.predicate = predicate
        request.propertiesToUpdate = propertiesToUpdate
        request.resultType = NSBatchUpdateRequestResultType.updatedObjectIDsResultType
        return request
    }
    
    private func finalCompletion(_ compl: (() -> Void)?) {
        let queue = delegateQueue == nil ? MyCoreDataManager.shared.completionQueue : delegateQueue!
        queue.async {
            compl?()
        }
    }
    
    // MARK: - Public funcs
    func startup(_ modelName: String, completion: ((MyCoreDataError?) -> Void)?) {
        MyCoreDataManager.shared.cacheOperation(self)
        MyCoreDataManager.shared.executionQueue.async(flags: .barrier) { [weak self] in
            guard let `self` = self else {return}
            var error: MyCoreDataError?
            let semaphore = DispatchSemaphore(value: 0)
            MyCoreDataStack.shared.loadPersistentContainer(modelName, completion: { (coredataError) in
                error = coredataError
                semaphore.signal()
            })
            semaphore.wait()
            MyCoreDataManager.shared.removeOperation(self)
            
            DispatchQueue.main.async {
                completion?(error)
            }
        }
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
    
    func convertObject<T: NSManagedObject>(_ object: T, toMain: Bool = false) -> T {
        var aContext: NSManagedObjectContext!
        if toMain {
            aContext = MyCoreDataStack.shared.managedObjectContext()
        }
        else {
            aContext = context
        }
        var obj = aContext.object(with: object.objectID) as! T
        if obj.isFault {
            do {
                obj = try aContext.existingObject(with: object.objectID) as! T
            } catch {
                print("CoreData - Failed to convert object \(object) - \(error)")
            }
        }
        return obj
    }
    
    func createObject<T: NSManagedObject>(_ entityClass: T.Type) -> T {
        return T(context: context)
    }
    
    func createObjectIfNeeded<T: NSManagedObject>(_ object: T?) -> T {
        if let obj = object {
            return convertObject(obj)
        }
        return createObject(T.self)
    }
    
    // MARK: Save
    func executeSave(_ completion: ((MyCoreDataOperation, MyCoreDataError?) -> Void)?) {
        // cache this operation
        MyCoreDataManager.shared.cacheOperation(self)
        
        var requestSemaphore: DispatchSemaphore?
        if !shouldRequestAsynchronously {
            requestSemaphore = DispatchSemaphore(value: 0)
        }
        
        var myError: MyCoreDataError?
        
        MyCoreDataManager.shared.executionQueue.async(flags: .barrier) { [weak self] in
            guard let `self` = self else {return}
            
            self.context.performAndWait { [weak self] in
                guard let `self` = self else {return}
                
                self.operating?(self)
                
                guard self.context.hasChanges else {return}
                do {
                    try self.context.save()
                }
                catch {
                    print("Coredata - Failed to save - error: \(error)")
                    myError = MyCoreDataError.SaveObjectFail
                }
            }
            requestSemaphore?.signal()
            
            // for async request
            if self.shouldRequestAsynchronously {
                self.finalCompletion {
                    completion?(self, myError)
                    MyCoreDataManager.shared.removeOperation(self)
                }
            }
        }
        
        requestSemaphore?.wait()
        
        // for sync request
        if !shouldRequestAsynchronously {
            completion?(self, myError)
            MyCoreDataManager.shared.removeOperation(self)
        }
    }
    
    // MARK: Fetch
    func executeFetch<T: NSManagedObject>(_ entityClass: T.Type, completion: ((MyCoreDataOperation, [T]?) -> Void)?) {
        // cache this operation
        MyCoreDataManager.shared.cacheOperation(self)
        
        var requestSemaphore: DispatchSemaphore?
        if !shouldRequestAsynchronously {
            requestSemaphore = DispatchSemaphore(value: 0)
        }
        
        var result: [T]?
        
        MyCoreDataManager.shared.executionQueue.async { [weak self] in
            guard let `self` = self else {return}
            
            let semaphore = DispatchSemaphore(value: 0)
            
            self.context.perform { [weak self] in
                guard let `self` = self else {return}
                
                self.operating?(self)
                
                do {
                    try self.context.execute(NSAsynchronousFetchRequest.init(fetchRequest: self.getFetchRequest(entityClass)) { (fetchResult) in
                        result = fetchResult.finalResult as? [T]
                        semaphore.signal()
                    })
                }
                catch {
                    print("Failed to fetch \(String(describing: T.self)) - error: \(error)")
                }
            }
            semaphore.wait()
            requestSemaphore?.signal()
            
            // for async request
            if self.shouldRequestAsynchronously {
                self.finalCompletion {
                    completion?(self, result)
                    MyCoreDataManager.shared.removeOperation(self)
                }
            }
        }
        
        // for sync request
        requestSemaphore?.wait()
        if !shouldRequestAsynchronously {
            completion?(self, result)
            MyCoreDataManager.shared.removeOperation(self)
        }
    }
    
    // MARK: Batch Update
    func executeBatchUpdate<T: NSManagedObject>(_ propertiesToUpdate: [AnyHashable: Any]?, entityClass: T.Type, completion: ((MyCoreDataOperation, MyCoreDataError?) -> Void)?) {
        // cache this operation
        MyCoreDataManager.shared.cacheOperation(self)
        
        var requestSemaphore: DispatchSemaphore?
        if !shouldRequestAsynchronously {
            requestSemaphore = DispatchSemaphore(value: 0)
        }
        
        var myError: MyCoreDataError?
        
        MyCoreDataManager.shared.executionQueue.async(flags: .barrier) { [weak self] in
            guard let `self` = self else {return}
            
            // prepare attributes
            self.propertiesToUpdate = propertiesToUpdate
            
            self.context.performAndWait { [weak self] in
                guard let `self` = self else {return}
                
                self.operating?(self)
                
                do {
                    let result = try self.context.execute(self.getUpdateRequest(entityClass)) as? NSBatchUpdateResult
                    print("CoreData - Did batch update: \(String(describing: result))")
                    MyCoreDataStack.shared.mergeChanges(result, context: self.context)
                }
                catch {
                    print("Failed to batch update \(String(describing: T.self)) - error: \(error)")
                    myError = MyCoreDataError.UpdateObjectFail
                }
            }
            requestSemaphore?.signal()
            
            // for async request
            if self.shouldRequestAsynchronously {
                self.finalCompletion {
                    completion?(self, myError)
                    MyCoreDataManager.shared.removeOperation(self)
                }
            }
        }
        
        // for sync request
        requestSemaphore?.wait()
        if !shouldRequestAsynchronously {
            completion?(self, myError)
            MyCoreDataManager.shared.removeOperation(self)
        }
    }
    
    // MARK: Delete
    func executeDelete(_ object: NSManagedObject, completion: ((MyCoreDataOperation, MyCoreDataError?) -> Void)?) {
        context.delete(object)
        return executeSave(completion)
    }
    
    deinit {
        print("=== CoreData Operation DEALLOC ===")
    }
}

fileprivate class MyCoreDataManager {
    static let shared = MyCoreDataManager()
    var operations = [String: MyCoreDataOperation]()
    let operationQueue = DispatchQueue.init(label: "com.mycoredata.operation")
    let executionQueue = DispatchQueue.init(label: "com.mycoredata.execution", attributes: .concurrent)
    let completionQueue = DispatchQueue.init(label: "com.mycoredata.completion", attributes: .concurrent)
    
    func cacheOperation(_ operation: MyCoreDataOperation) {
        operationQueue.sync { [weak self] in
            guard let `self` = self else {return}
            operation._id = NSUUID.createBaseTime()
            self.operations[operation._id] = operation
        }
    }
    
    func removeOperation(_ operation: MyCoreDataOperation) {
        operationQueue.sync { [weak self] in
            guard let `self` = self else {return}
            self.operations.removeValue(forKey: operation._id)
        }
    }
}

fileprivate class MyCoreDataStack {
    
    static let shared: MyCoreDataStack = {
        let stack = MyCoreDataStack()
        
//        NotificationCenter.default.addObserver(stack, selector: #selector(MyCoreDataStack.contextChange(_:)), name:NSNotification.Name.NSManagedObjectContextDidSave , object: nil)
//        NotificationCenter.default.addObserver(stack, selector: #selector(MyCoreDataStack.contextChange(_:)), name:NSNotification.Name.NSManagedObjectContextObjectsDidChange , object: nil)
        
        return stack
    }()
    
//    @objc func contextChange(_ notification: Notification) {
//        print("CoreData - contextChange: \(notification)")
//    }
    
    // MARK: - Core Data stack
    private var persistentContainer: NSPersistentContainer!
    
    lazy private var backgroundContext: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        applyContextAttributes(context)
        return context
    }()
    
    lazy private var contexts: NSHashTable<NSManagedObjectContext> = {
        let _contexts = NSHashTable<NSManagedObjectContext>(options: NSPointerFunctions.Options.weakMemory)
        _contexts.add(persistentContainer.viewContext)
        _contexts.add(backgroundContext)
        return _contexts
    }()
    
    func loadPersistentContainer(_ modelName: String, completion: ((MyCoreDataError) -> Void)?) {
        initializePersistentContainer(modelName) { [weak self] (error) in
            guard let `self` = self else {return}
            self.applyContextAttributes(self.persistentContainer.viewContext)
            completion?(error)
        }
    }
    
    private func initializePersistentContainer(_ modelName: String, completion: ((MyCoreDataError) -> Void)?) {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        guard let modelPath = applicationDocumentsDirectory()?.appendingPathComponent(modelName + ".sqlite") else {
            completion?(MyCoreDataError.InvalidStoreURL)
            return
        }
        
        let description = NSPersistentStoreDescription(url: modelPath)
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        description.shouldAddStoreAsynchronously = true
        
        persistentContainer = NSPersistentContainer(name: modelName)
        persistentContainer.persistentStoreDescriptions = [description]
        persistentContainer.loadPersistentStores(completionHandler: { (storeDescription, error) in
            print("CoreData - Did load model at path: \(modelPath.path)")
            var err = MyCoreDataError.Unknown
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
    
    private func applyContextAttributes(_ context: NSManagedObjectContext) {
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
    }
    
    func applicationDocumentsDirectory() -> URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
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
            contexts.add(newContext)
            return newContext
        }
    }
    
    func mergeChanges(_ batchUpdateResult: NSBatchUpdateResult?, context: NSManagedObjectContext) {
        guard let objectIDs = batchUpdateResult?.result as? [NSManagedObjectID] else {return}
        let changes = [NSUpdatedObjectsKey: objectIDs]
//        let remainContexts = contexts.allObjects.filter({ $0 != context })
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: contexts.allObjects)
    }
    
    func managedObjectModel() -> NSManagedObjectModel {
        return persistentContainer.managedObjectModel
    }
    
    func persistentStoreCoordinator() -> NSPersistentStoreCoordinator {
        return persistentContainer.persistentStoreCoordinator
    }
}
