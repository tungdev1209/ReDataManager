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
    
    @IBOutlet weak var playerView: UIView!
    var catTitle: String = ""
    
    let cleanPlayerBag = CleanPlayerBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.backgroundColor = UIColor.lightGray
        
        let videoSkinView = Bundle.main.loadNibNamed("VideoSkin", owner: nil, options: nil)?.first as! VideoSkin
        videoSkinView.frame = playerView.bounds
//        videoSkinView.backgroundColor = UIColor.blue
        playerView.addSubview(videoSkinView)
        
        initilizeVideo()
    }
    
    func initilizeVideo() {
        guard let url = URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8") else {return}
        MyPlayerController(url).configuration(MyPlayerConfiguration().shouldPlayAfterLoaded(true))
            .execute({ [weak self] (controller) in
                guard let `self` = self else {return}
                guard controller.error == nil else {return}
                self.playerView.addSubview(controller.playerView)
                self.playerView.sendSubviewToBack(controller.playerView)
                controller.playerView.frame = self.playerView.bounds
            }).cleanBy(cleanPlayerBag)
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
        MyCoreDataOperation(.Background)
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
        MyCoreDataOperation.unload()
    }
}
