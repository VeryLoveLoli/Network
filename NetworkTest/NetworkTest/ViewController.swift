//
//  ViewController.swift
//  NetworkTest
//
//  Created by 韦烽传 on 2019/4/19.
//  Copyright © 2019 韦烽传. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var button: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        imageView.load("http://i0.hdslb.com/bfs/archive/24e031e495699e234526586deb80c65d337cbe4d.png", defaultImage: nil, isCache: true, isDisk: true) { (current, total) in

            print("image - \(current)/\(total) - \(String.init(format: "%.2f", Float(current)/Float(total)*100))%")
        }
        
        button.load("http://i0.hdslb.com/bfs/archive/24e031e495699e234526586deb80c65d337cbe4d.png", isBackground: false, state: .normal, defaultImage: nil, isCache: true, isDisk: true) { (current, total) in
            
            print("button - \(current)/\(total) - \(String.init(format: "%.2f", Float(current)/Float(total)*100))%")
        }
        
        button.load("http://i0.hdslb.com/bfs/archive/24e031e495699e234526586deb80c65d337cbe4d.png", isBackground: true, state: .normal, defaultImage: nil, isCache: true, isDisk: true) { (current, total) in
            
            print("button - background - \(current)/\(total) - \(String.init(format: "%.2f", Float(current)/Float(total)*100))%")
        }

        
//        Network.default.load("http://i0.hdslb.com/bfs/archive/24e031e495699e234526586deb80c65d337cbe4d.png") { (error, data, path) in
//
//            print(error)
//            print(data?.count)
//            print(path)
//        }
    }


}

