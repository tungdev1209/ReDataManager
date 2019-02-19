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
        
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
    }

    func testStartup() {
        let setupExpectation = expectation(description: "background context")
        
        MyCoreDataOperation.startup(MyCoreDataOperationConfiguration(Bundle.main.getAppName())
            .storeType(MyCoreDataStoreType.InMemory))
        { (error) in
            print("Did startup - \(error == nil)")
            setupExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
