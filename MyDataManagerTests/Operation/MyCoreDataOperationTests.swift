//
//  MyCoreDataOperationTests.swift
//  MyDataManagerTests
//
//  Created by Tung Nguyen on 11/18/18.
//  Copyright © 2018 Tung Nguyen. All rights reserved.
//

import XCTest
import CoreData
@testable import MyDataManager

// https://medium.com/flawless-app-stories/cracking-the-tests-for-core-data-15ef893a3fee

class MyCoreDataLifeCycleTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
    }

    func testStartupAsynchronously() {
        let setupExpectation = expectation(description: "coredata startup")
        let managedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle(for: type(of: self))])
        
        var err: MyCoreDataError?
        MyCoreDataOperation.startup(MyCoreDataOperationConfiguration(Bundle.main.getAppName())
            .storeType(MyCoreDataStoreType.InMemory)
            .managedObjectModel(managedObjectModel!))
        { (error) in
            print("Did startup - \(error == nil)")
            err = error
            setupExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        XCTAssertTrue(err == nil)
        
        MyCoreDataOperation.unload()
    }
    
    func testStartupSynchronously() {
        let managedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle(for: type(of: self))])
        MyCoreDataOperation.startup(MyCoreDataOperationConfiguration(Bundle.main.getAppName())
            .storeType(MyCoreDataStoreType.InMemory)
            .managedObjectModel(managedObjectModel!)
            .shouldLoadStoreAsynchronously(false))
        { (error) in
            print("Did startup - \(error == nil)")
            XCTAssertTrue(error == nil)
        }
        
        MyCoreDataOperation.unload()
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

class MyCoreDataExecutionTests: XCTestCase {
    
    var tests: MyCoreDataObjectLifeCycleTests?
    var asyncTests: MyCoreDataObjectLifeCycleTestsAsynchronously?
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        let managedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle(for: type(of: self))])
        MyCoreDataOperation.startup(MyCoreDataOperationConfiguration(Bundle.main.getAppName())
            .storeType(MyCoreDataStoreType.InMemory)
            .managedObjectModel(managedObjectModel!)
            .shouldLoadStoreAsynchronously(false))
        { (error) in
            print("Did startup - \(error == nil)")
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
        tests?.delete()
        
        _ = asyncTests?.operation.shouldRequestAsynchronously(false)
        asyncTests?.delete()
        
        MyCoreDataOperation.unload()
    }
    
    func testMainContext() {
        tests = MyCoreDataObjectLifeCycleTests()
        tests?.operationMode = .Main
        tests?.run()
    }
    
    func testBackgroundContext() {
        tests = MyCoreDataObjectLifeCycleTests()
        tests?.operationMode = .Background
        tests?.run()
    }
    
    func testBackgroundScopedContext() {
        tests = MyCoreDataObjectLifeCycleTests()
        tests?.operationMode = .BackgroundScoped
        tests?.run()
    }
    
    func testMainContextAsync() {
        asyncTests = MyCoreDataObjectLifeCycleTestsAsynchronously()
        asyncTests?.operationMode = .Main
        asyncTests?.run()
    }
    
    func testBackgroundContextAsync() {
        asyncTests = MyCoreDataObjectLifeCycleTestsAsynchronously()
        asyncTests?.operationMode = .Background
        asyncTests?.run()
    }
    
    func testBackgroundScopedContextAsync() {
        asyncTests = MyCoreDataObjectLifeCycleTestsAsynchronously()
        asyncTests?.operationMode = .BackgroundScoped
        asyncTests?.run()
    }
}

class MyCoreDataObjectLifeCycleTestsAsynchronously {
    
    var operationMode = MyCoreDataMode.Unknown
    var operation: MyCoreDataOperation {
        return MyCoreDataOperation(operationMode)
    }
    
    func run() {
        save()
        fetch()
        delete()
    }
    
    func save() {
        let expectation = XCTestExpectation(description: "Saved")
        operation.operating({ (op) in
            var category = NSEntityDescription.insertNewObject(forEntityName: String(describing: Category.self), into: op.context!)
            category.setValue("Test", forKey: #keyPath(Category.title))
            category.setValue("Testing...", forKey: #keyPath(Category.subTitle))
            
            category = NSEntityDescription.insertNewObject(forEntityName: String(describing: Category.self), into: op.context!)
            category.setValue("Test1", forKey: #keyPath(Category.title))
            category.setValue("Testing1...", forKey: #keyPath(Category.subTitle))
            
            category = NSEntityDescription.insertNewObject(forEntityName: String(describing: Category.self), into: op.context!)
            category.setValue("Test1", forKey: #keyPath(Category.title))
            category.setValue("Testing2...", forKey: #keyPath(Category.subTitle))
            
            let movie = NSEntityDescription.insertNewObject(forEntityName: String(describing: Movie.self), into: op.context!)
            movie.setValue("GOT", forKey: #keyPath(Movie.title))
        }).executeSave { (_, error) in
            XCTAssertTrue(error == nil)
            
            expectation.fulfill()
        }
        
        let result = XCTWaiter().wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(result == .completed)
    }
    
    func fetch() {
        let expectationCat = XCTestExpectation(description: "Category Fetched")
        operation.fetchLimit(1)
            .predicate(NSPredicate(format: "%K == %@", #keyPath(Category.title), "Test1"))
            .executeFetch(String(describing: Category.self)) { (_, cats) in
                XCTAssertEqual(cats?.count, 1)
                
                let title = cats?.first?.value(forKey: #keyPath(Category.title)) as? String
                XCTAssertEqual(title, "Test1")
                
                expectationCat.fulfill()
        }
        
        let expectationMov = XCTestExpectation(description: "Movie Fetched")
        operation.predicate(nil)
            .executeFetch(String(describing: Movie.self)) { (_, movs) in
                let title = movs?.first?.value(forKey: #keyPath(Movie.title)) as? String
                XCTAssertEqual(title, "GOT")
                
                expectationMov.fulfill()
        }
        
        let result = XCTWaiter().wait(for: [expectationCat, expectationMov], timeout: 1.0)
        XCTAssertTrue(result == .completed)
    }
    
    func delete() {
        let expectationCat = XCTestExpectation(description: "Category Fetched")
        operation.executeFetch(String(describing: Category.self)) { (op, cats) in
            guard let cats = cats else {return}
            for cat in cats {
                op.executeDelete(cat)
            }
            op.executeSave({ (_, error) in
                XCTAssertNil(error)
                
                expectationCat.fulfill()
            })
        }
        
        var exps = [expectationCat]
        operation.executeFetch(String(describing: Movie.self)) { (op, movs) in
            guard let movs = movs else {return}
            for mov in movs {
                let exp = XCTestExpectation(description: "Movie Fetched")
                exps.append(exp)
                op.executeDelete(mov, save: true, completion: { (_, error) in
                    XCTAssertNil(error)
                    exp.fulfill()
                })
            }
        }
        
        let result = XCTWaiter().wait(for: exps, timeout: 10.0)
        XCTAssertTrue(result == .completed)
    }
}

class MyCoreDataObjectLifeCycleTests {
    
    var operationMode = MyCoreDataMode.Unknown
    var operation: MyCoreDataOperation {
        return MyCoreDataOperation(operationMode).shouldRequestAsynchronously(false)
    }
    
    func run() {
        save()
        fetch()
        delete()
    }
    
    func save() {
        operation.operating({ (op) in
            let category = NSEntityDescription.insertNewObject(forEntityName: String(describing: Category.self), into: op.context!)
            category.setValue("Test", forKey: #keyPath(Category.title))
            category.setValue("Testing...", forKey: #keyPath(Category.subTitle))
            
            let movie = NSEntityDescription.insertNewObject(forEntityName: String(describing: Movie.self), into: op.context!)
            movie.setValue("GOT", forKey: #keyPath(Movie.title))
        }).executeSave { (_, error) in
            XCTAssertTrue(error == nil)
        }
    }
    
    func fetch() {
        operation.executeFetch(String(describing: Category.self)) { (_, cats) in
            let title = cats?.first?.value(forKey: #keyPath(Category.title)) as? String
            XCTAssertEqual(title, "Test")
        }
        
        operation.executeFetch(String(describing: Movie.self)) { (_, movs) in
            let title = movs?.first?.value(forKey: #keyPath(Movie.title)) as? String
            XCTAssertEqual(title, "GOT")
        }
    }
    
    func delete() {
        operation.executeFetch(String(describing: Category.self)) { (op, cats) in
            guard let cats = cats else {return}
            for cat in cats {
                op.executeDelete(cat)
            }
            op.executeSave({ (_, error) in
                XCTAssertNil(error)
            })
        }
        
        operation.executeFetch(String(describing: Movie.self)) { (op, movs) in
            guard let movs = movs else {return}
            for mov in movs {
                op.executeDelete(mov, save: true, completion: { (_, error) in
                    XCTAssertNil(error)
                })
            }
        }
    }
}
