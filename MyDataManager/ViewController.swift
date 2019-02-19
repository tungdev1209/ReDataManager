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

let key: [UInt8] = [0x9F, 0x9C, 0x72, 0x79, 0xF6, 0x8A, 0x1E, 0x38, 0x65, 0x22, 0xE1, 0x16, 0x3A, 0xF0, 0x61, 0x07, 0x0A, 0xD2, 0x7C, 0xCF, 0x93, 0x45, 0x79, 0xB4, 0x9C, 0xA0, 0xED, 0xCC, 0xFE, 0x82, 0xDF, 0xF4]
let iv: [UInt8] = [0xB7, 0x6A, 0x45, 0x6B, 0x43, 0x2C, 0x00, 0xA1, 0x86, 0x78, 0x8E, 0xB2, 0x35, 0xF6, 0x59, 0x3D]

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
        navigationController?.pushViewController(vc, animated: true)
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
