//
//  File.swift
//  
//
//  Created by 韦烽传 on 2021/2/2.
//

import Foundation

#if os(iOS) || os(watchOS) || os(tvOS)
import UIKit
#endif

/**
 数据缓存
 */
open class DataCache {
    
    /// 默认数据缓存
    public static let `default` = DataCache.init("DataCache")
    
    /// 缓存数据
    private var dictionary: Dictionary<String, Data> = [:]
    /// 队列
    private var serialQueue: DispatchQueue
    
    // MARK: - init
    
    public init(_ name: String) {
        
        serialQueue = DispatchQueue.init(label: name + ".serial")
        
        #if os(iOS) || os(watchOS) || os(tvOS)
        /// 注册内存警告
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { [weak self] (notification) in
            
            /// 删除缓存
            self?.removeAll()
        }
        #endif
    }
    
    // MARK: - Data
    
    open func get(_ key: String) -> Data? {
        
        let dispatchSemaphore = DispatchSemaphore.init(value: 0)
        
        var data: Data? = nil
        
        serialQueue.async {
            
            data = self.dictionary[key]
            dispatchSemaphore.signal()
        }
        
        dispatchSemaphore.wait()
        
        return data
    }
    
    open func add(_ key: String, data: Data) {
        
        serialQueue.async {
            
            self.dictionary[key] = data
        }
    }
    
    open func remove(_ key: String) {
        
        serialQueue.async {
            
            self.dictionary.removeValue(forKey: key)
        }
    }
    
    open func removeAll() {
        
        serialQueue.async {
            
            self.dictionary.removeAll()
        }
    }
}
