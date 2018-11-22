//
//  MyCoreDataOperationTests.swift
//  MyDataManagerTests
//
//  Created by Tung Nguyen on 11/18/18.
//  Copyright © 2018 Tung Nguyen. All rights reserved.
//

import XCTest

// https://medium.com/flawless-app-stories/cracking-the-tests-for-core-data-15ef893a3fee

class MyCoreDataOperationTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        MyCoreDataOperation.startup(MyCoreDataOperationConfiguration(Bundle.main.getAppName())
            .storeType(MyCoreDataStoreType.InMemory)
            .shouldLoadStoreAsynchronously(false))
        { (error) in
            print("Did startup - \(error == nil)")
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
        MyCoreDataOperation(.Background).executeFetch(Category.self) { (operation, cats) in
            cats?.forEach({ (cat) in
                operation.executeDelete(cat)
            })
            operation.executeSave({ (_, error) in
                print("Did flush data - \(error == nil)")
            })
        }
    }

    func testSave() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        MyCoreDataOperation(.Background).operating({ (operation) in
            let category = operation.createObject(Category.self)
            category.title = "Action"
        }).executeSave { (_, error) in
            
        }
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
