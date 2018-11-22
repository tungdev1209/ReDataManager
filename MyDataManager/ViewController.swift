//
//  ViewController.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 11/18/18.
//  Copyright © 2018 Tung Nguyen. All rights reserved.
//

import UIKit

// https://qualitycoding.org/tdd-sample-archives/
// https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/08-automation.html#//apple_ref/doc/uid/TP40014132-CH7-SW1

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        MyCoreDataOperation.startup(MyCoreDataOperationConfiguration(Bundle.main.getAppName())
            .storeType(MyCoreDataStoreType.SQLite)
            .shouldLoadStoreAsynchronously(true))
        { (error) in
            print("Did startup - \(error == nil)")
            
            MyCoreDataOperation(.Background).operating({ (operation) in
                let category = operation.createObject(Category.self)
                category.title = "Action"
            }).executeSave { (_, error) in
                print("Did save - \(error == nil)")
            }
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                MyCoreDataOperation(.Background).executeBatchDelete(Category.self) { (_, error) in
                    print("Did flush data - \(error == nil)")
                }
            })
        }
    }

}

