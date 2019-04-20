//
//  ViewController.swift
//  NetworkTest Mac
//
//  Created by 韦烽传 on 2019/4/20.
//  Copyright © 2019 韦烽传. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var button: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        imageView.load("http://i0.hdslb.com/bfs/archive/24e031e495699e234526586deb80c65d337cbe4d.png", defaultImage: nil, isCache: false, isDisk: true) { (current, total) in

            print("\(current)/\(total) - \(String.init(format: "%.2f", Float(current)/Float(total)*100))%")
        }
        
        button.load("http://i0.hdslb.com/bfs/archive/24e031e495699e234526586deb80c65d337cbe4d.png", isAlternate: false, defaultImage: nil, isCache: true, isDisk: true) { (current, total) in

            print("\(current)/\(total) - \(String.init(format: "%.2f", Float(current)/Float(total)*100))%")
        }
        
        /// button.alternateImage 设置图片不显示。。。
        
        button.load("http://i0.hdslb.com/bfs/archive/f612c0b3c80c42aa2f00de067f4c11f0ef873ac1.png", isAlternate: true, defaultImage: nil, isCache: true, isDisk: true) { (current, total) in
            
            print("\(current)/\(total) - \(String.init(format: "%.2f", Float(current)/Float(total)*100))%")
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}
