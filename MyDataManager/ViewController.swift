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
// https://www.apriorit.com/dev-blog/436-data-encryption-ios
// openssl enc -aes-256-cbc -k password -P -md sha1

class ViewController: UIViewController {

    @IBOutlet weak var listCategoryTblView: UITableView!
    let cells = ["A", "B", "C"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        title = "Main"
        
        MyKeychainService.shared.configuration = MyKeyChainConfiguration()
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let vc = storyboard?.instantiateViewController(withIdentifier: String(describing: CategoryViewController.self)) as? CategoryViewController else {return}
        vc.catTitle = cells[indexPath.row]
        MyCoreDataOperation
            .startup(MyCoreDataOperationConfiguration(Bundle.main.getAppName())
                .modelPath("category/\(cells[indexPath.row])")
                .protection(true))
            { [weak self] (error) in
                guard let `self` = self else {return}
                print("Did startup - \(error == nil)")
                self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") as! CategoryTableViewCell
        cell.textLabel?.text = cells[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
}
