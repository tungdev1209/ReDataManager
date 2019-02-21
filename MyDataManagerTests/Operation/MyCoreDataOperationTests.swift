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
    var tempObject: NSManagedObject?
    
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
        
        operation = MyCoreDataOperation(.Main).shouldRequestAsynchronously(false)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
        if let obj = tempObject {
            operation.executeDelete(obj, save: true) { (_, error) in
                print("Did reset all testing memory - \(String(describing: error?.toString()))")
            }
        }
        
        MyCoreDataOperation.unload()
    }
    
    func testSave() {
        var err: MyCoreDataError?
        operation.operating({ [weak self] (op) in
            guard let `self` = self else {return}
            self.tempObject = NSEntityDescription.insertNewObject(forEntityName: "Category", into: op.context!)
            self.tempObject?.setValue("Test", forKey: "title")
            self.tempObject?.setValue("Testing...", forKey: "subTitle")
            print(self.tempObject)
        }).executeSave { (_, error) in
            print("Did save - \(error == nil)")
            err = error
        }
        XCTAssertTrue(err == nil)
    }
    
}
