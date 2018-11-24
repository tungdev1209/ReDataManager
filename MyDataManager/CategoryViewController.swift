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
    
    var catTitle: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.backgroundColor = UIColor.lightGray
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !catTitle.isEmpty {
            MyCoreDataOperation(.Background)
                .delegateQueue(DispatchQueue.main)
                .predicate(NSPredicate(format: "%K == %@", #keyPath(Category.title), catTitle))
                .executeFetch(Category.self)
                { [weak self] (_, cats) in
                    guard let `self` = self else {return}
                    guard let cat = cats?.first else {return}
                    self.title = cat.subTitle
            }
        }
    }
    
    @IBAction func btnSavePressed(_ sender: Any) {
        MyCoreDataOperation(.BackgroundScoped)
            .predicate(NSPredicate(format: "%K == %@", #keyPath(Category.title), catTitle))
            .executeFetch(Category.self, completion: { [weak self] (operation, cats) in
                guard let `self` = self else {return}
                guard let cat = operation.createObjectIfNeeded(cats?.first) else {return}
                DispatchQueue.main.sync { [weak self] in
                    guard let `self` = self else {return}
                    cat.subTitle = self.titleTf.text
                }
                cat.title = self.catTitle
                operation.delegateQueue(DispatchQueue.main)
                    .executeSave({ [weak self] (_, error) in
                        guard let `self` = self else {return}
                        print("Did save - \(String(describing: error))")
                        if error == nil {
                            self.title = self.titleTf.text
                        }
                    })
            })
    }
    
    deinit {
        MyCoreDataOperation.cleanup()
    }
}
