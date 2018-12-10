//
//  VideoSkin.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 12/9/18.
//  Copyright © 2018 Tung Nguyen. All rights reserved.
//

import UIKit

class VideoSkin: UIView {
    @IBOutlet weak var btnPlay: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        print(toString())
        btnPlay.addTarget(self, action: #selector(play), for: UIControl.Event.touchUpInside)
    }
    
    @objc func play() {
        
    }
}
