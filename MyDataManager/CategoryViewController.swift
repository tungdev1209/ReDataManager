//
//  CategoryViewController.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 11/23/18.
//  Copyright © 2018 Tung Nguyen. All rights reserved.
//

import UIKit

class CategoryViewController: UIViewController {

    @IBOutlet weak var titleTf: UITextField!
    @IBOutlet weak var saveBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.backgroundColor = UIColor.lightGray
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        MyCoreDataOperation(.Background).executeFetch(Category.self) { (_, <#[T]?#>) in
            <#code#>
        }
    }
    
    @IBAction func btnSavePressed(_ sender: Any) {
        MyCoreDataOperation(.Main).operating({ [weak self] (operation) in
            guard let `self` = self else {return}
            let category = operation.createObject(Category.self)
            category.title = self.titleTf.text
        }).executeSave { (_, error) in
            print("Did save - \(error == nil)")
        }
    }
    
}
