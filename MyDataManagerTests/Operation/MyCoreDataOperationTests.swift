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

class MyCoreDataSaveExecutionTests: XCTestCase {
    
    var operation: MyCoreDataOperation!
    
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
        
        operation = MyCoreDataOperation(.Main)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
        operation.shouldRequestAsynchronously(false)
            .executeBatchDelete(Category.self) { (_, error) in
            print("Did reset all testing memory")
        }
        MyCoreDataOperation.unload()
    }
    
    func testSave() {
        let setupExpectation = expectation(description: "coredata startup")
        operation.operating({ (op) in
            let cat = op.createObject(Category.self)
            cat?.title = "Test"
            cat?.subTitle = "Testing..."
        }).executeSave { (_, error) in
            print("Did save - \(error == nil)")
            XCTAssertTrue(error == nil)
            setupExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
}
