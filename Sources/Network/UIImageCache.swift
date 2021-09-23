//
//  File.swift
//  
//
//  Created by 韦烽传 on 2021/2/2.
//

import Foundation

#if os(iOS) || os(watchOS) || os(tvOS)

import UIKit

/**
 图片缓存
 */
open class UIImageCache: NSCache<NSString, UIImage> {
    
    public static let `default` = UIImageCache.init()
    
    override public init() {
        
        super.init()
        
        /// 注册内存警告
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: OperationQueue.main) { [weak self] (notification) in
            
            /// 删除缓存
            self?.removeAllObjects()
        }
    }
}
#endif
