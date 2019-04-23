//
//  Network.swift
//  NetworkTest
//
//  Created by 韦烽传 on 2019/4/19.
//  Copyright © 2019 韦烽传. All rights reserved.
//

import Foundation

/// 网络进度回调
public typealias NetworkCallbackProgress = (Int64, Int64)->Void
/// 网络结果回调
public typealias NetworkCallbackResult = (Error?, Data?, String?)->Void
/// 网络回调
public typealias NetworkCallback = (NetworkCallbackProgress, NetworkCallbackResult)

/**
 网络
 */
public class Network: NetworkOperationDelegate {
    
    /// 默认网络
    public static let `default` = Network.init()
    
    /// 并行队列（用于下载）
    private var concurrentQueue: DispatchQueue
    /// 串行队列（用于处理等待列表、运行列表）
    private var serialQueue: DispatchQueue
    /// 等待列表
    private var waitList: [NetworkOperation] = []
    /// 运行列表
    private var runList: [NetworkOperation] = []
    /// 请求与回调列表
    private var requestCallback: [String: [String]] = [:]
    /// 回调字典
    private var callback: [String: NetworkCallback] = [:]
    /// 最大并发数量
    public var maxConcurrent = Int.max { didSet { exceedMaxRunToWait(); nextRun() } }
    /// 磁盘文件夹路径
    public private(set) var path: String
    
    // MARK: - init
    
    public init(_ name: String, max: Int, directory: String) {
        
        concurrentQueue = DispatchQueue.init(label: name + ".concurrent", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
        serialQueue = DispatchQueue.init(label: name + ".serial")
        maxConcurrent = max
        path = directory
        
        createDirectory()
    }
    
    private convenience init() {
        
        self.init("Network", max: 3, directory: NSHomeDirectory() + "/Documents/Network/")
    }
    
    // MARK: - Load
    
    /**
     加载
     
     - parameter    urlString:  地址字符串
     - parameter    isDisk:     是否磁盘存储
     - parameter    isStart:    是否立即开始
     - parameter    callbackID: 回调ID(用于取消 progress、result)
     - parameter    progress:   进度  (当前字节,总字节)
     - parameter    result:     结果  (错误信息,数据(isDisk = false 有值),数据路径(isDisk = true 有值))
     */
    public func load(_ urlString: String,
                     isDisk: Bool = false,
                     isStart: Bool = true,
                     callbackID: String = "\(Date.init().timeIntervalSince1970)-\(arc4random())",
                     progress: @escaping NetworkCallbackProgress = { _,_ in },
                     result: @escaping NetworkCallbackResult) {

        if let url = URL.init(string: urlString) {
            
            load(url, isDisk: isDisk, isStart: isStart, progress: progress, result: result)
        }
    }
    
    /**
     加载
     
     - parameter    url:        地址
     - parameter    isDisk:     是否磁盘存储
     - parameter    isStart:    是否立即开始
     - parameter    callbackID: 回调ID(用于取消 progress、result)
     - parameter    progress:   进度  (当前字节,总字节)
     - parameter    result:     结果  (错误信息,数据(isDisk = false 有值),数据路径(isDisk = true 有值))
     */
    public func load(_ url: URL,
                     isDisk: Bool = false,
                     isStart: Bool = true,
                     callbackID: String = "\(Date.init().timeIntervalSince1970)-\(arc4random())",
                     progress: @escaping NetworkCallbackProgress = { _,_ in },
                     result: @escaping NetworkCallbackResult) {

        load(URLRequest.init(url: url), isDisk: isDisk, isStart: isStart, progress: progress, result: result)
    }
    
    /**
     加载
     
     - parameter    request:    URL请求
     - parameter    isDisk:     是否磁盘存储
     - parameter    isStart:    是否立即开始
     - parameter    callbackID: 回调ID(用于取消 progress、result)
     - parameter    progress:   进度  (当前字节,总字节)
     - parameter    result:     结果  (错误信息,数据(isDisk = false 有值),数据路径(isDisk = true 有值))
     */
    public func load(_ request: URLRequest,
                     isDisk: Bool = false,
                     isStart: Bool = true,
                     callbackID: String = "\(Date.init().timeIntervalSince1970)-\(arc4random())",
                     progress: @escaping NetworkCallbackProgress = { _,_ in },
                     result: @escaping NetworkCallbackResult) {
        
        if let key = NetworkOperation.key(request) {
            
            let operation = NetworkOperation.init(key, request: request, path: isDisk ? (path + key) : nil, delegate: self)
            
            addCallback(key, id: callbackID, callback: (progress, result))

            if isStart {
                
                addRun(operation)
            }
            else {
                
                addWait(operation)
            }
        }
    }
    
    // MARK: - Operation Queue
    
    /**
     添加运行
     */
    private func addRun(_ operation: NetworkOperation) {
        
        self.serialQueue.async {
            
            /// 判断是否已在运行
            for run in self.runList {
                
                if run.key == operation.key {
                    
                    return
                }
            }
            
            /// 从等待列表中删除
            _ = self.removeWait(operation.key)
            
            /// 加入运行列表
            self.runList.insert(operation, at: 0)
            
            /// 运行
            self.concurrentQueue.async {
                
                operation.start()
            }
            
            self.exceedMaxRunToWait()
        }
    }
    
    /**
     添加等待
     */
    private func addWait(_ operation: NetworkOperation) {
        
        self.serialQueue.async {
            
            /// 判断是否已在运行
            for run in self.runList {
                
                if run.key == operation.key {
                    
                    return
                }
            }
            
            /// 是否已存在
            var isExist = false
            
            for wait in self.waitList {
                
                if wait.key == operation.key {
                    
                    isExist = true
                    break
                }
            }
            
            if !isExist {
                
                /// 加入等待列表
                self.waitList.append(operation)
            }
        }
        
        nextRun()
    }
    
    /**
     删除
     
     - parameter    key:        操作标识    (外部调用需通过 NetworkOperation.key() 获取 )
     */
    public func remove(_ key: String) {
        
        self.serialQueue.async {
            
            self.removeRequestCallback(key)
            
            if self.removeRun(key) {
                
            }
            else if self.removeWait(key) {
                
            }
        }
    }
    
    /**
     从运行列表中删除
     */
    private func removeRun(_ key: String) -> Bool {
        
        for i in 0..<self.runList.count {
            
            if self.runList[i].key == key {
                
                self.runList[i].cancel()
                self.runList.remove(at: i)
                
                return true
            }
        }
        
        return false
    }
    
    /**
     从等待列表中删除
     */
    private func removeWait(_ key: String) -> Bool {
        
        for i in 0..<self.waitList.count {
            
            if self.waitList[i].key == key {
                
                self.waitList.remove(at: i)
                
                return true
            }
        }
        
        return false
    }
    
    /**
     将过多的运行放入等待列表
     */
    private func exceedMaxRunToWait() {
        
        self.serialQueue.async {
            
            while self.runList.count > self.maxConcurrent && self.runList.count > 1 {
                
                let last = self.runList.remove(at: self.runList.count - 1)
                
                if !last.isFinished {
                    
                    last.cancel()
                    self.waitList.insert(NetworkOperation.init(last.key, request: last.request, path: last.path, delegate: self), at: 0)
                }
            }
        }
    }
    
    /**
     下一个运行
     */
    private func nextRun() {
        
        self.serialQueue.async {
            
            while self.runList.count < self.maxConcurrent && self.waitList.count > 0 {
                
                let operation = self.waitList.remove(at: 0)
                self.runList.insert(operation, at: 0)
                
                self.concurrentQueue.async {
                    
                    operation.start()
                }
            }
        }
    }
    
    // MARK: - Callback
    
    /**
     添加回调
     
     - parameter    key:        操作标识
     - parameter    id:         回调ID
     - parameter    callback:   回调
     */
    private func addCallback(_ key: String, id: String, callback: NetworkCallback) {
        
        self.serialQueue.async {
            
            self.callback[id] = callback
            
            if self.requestCallback[key] == nil {
                
                self.requestCallback[key] = [id]
            }
            else {
                
                self.requestCallback[key]?.append(id)
            }
        }
    }
    
    /**
     删除请求回调
     
     - parameter    key:        操作标识
     */
    private func removeRequestCallback(_ key: String) {
        
        self.serialQueue.async {
            
            if let callbackIDList = self.requestCallback.removeValue(forKey: key) {
                
                for id in callbackIDList {
                    
                    self.callback.removeValue(forKey: id)
                }
            }
        }
    }
    
    /**
     删除回调
     
     - parameter    id:         回调ID    (外部调用需在 load() 时 设置)
     */
    public func removeCallback(_ id: String) {
        
        self.serialQueue.async {
            
            self.callback.removeValue(forKey: id)
        }
    }
    
    /**
     回调进度
     
     - parameter    key:        操作标识
     - parameter    current:    当前字节
     - parameter    total:      总字节
     */
    private func callbackProgress(_ key: String, current: Int64, total: Int64) {
        
        self.serialQueue.async {
            
            if let callbackIDList = self.requestCallback[key] {
                
                for id in callbackIDList {
                    
                    if let (progress, _) = self.callback[id] {
                        
                        self.concurrentQueue.async {
                            
                            progress(current, total)
                        }
                    }
                }
            }
        }
    }
    
    /**
     回调结果
     
     - parameter    key:        操作标识
     - parameter    error:      错误信息
     - parameter    data:       数据
     - parameter    path:       路径
     */
    private func callbackResult(_ key: String, error: Error?, data: Data?, path: String?) {
        
        self.serialQueue.async {
            
            if let callbackIDList = self.requestCallback[key] {
                
                for id in callbackIDList {
                    
                    if let (_, result) = self.callback[id] {
                    
                        self.concurrentQueue.async {
                            
                            result(error, data, path)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - FileManager
    
    /**
     创建文件夹
     */
    private func createDirectory() {
        
        /// 文件管理
        let fileManager: FileManager = FileManager.default
        
        /// 判断文件夹是否存在
        if !fileManager.fileExists(atPath: path) {
            
            do {
                /// 创建文件夹
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                
            } catch {
                
            }
        }
    }
    
    /**
     删除磁盘文件
     
     - parameter    key:        操作标识    (外部调用需通过 NetworkOperation.key() 获取 )
     */
    public func removeDiskFile(_ key: String) {
        
        self.concurrentQueue.async {
            
            /// 文件管理
            let fileManager = FileManager.default
            
            do {
                /// 删除文件
                try fileManager.removeItem(atPath: self.path + key)
                try fileManager.removeItem(atPath: self.path + key + ".cache")
            } catch  {
                
            }
        }
    }
    
    /**
     删除所有磁盘文件
     */
    public func removeAllDiskFile() {
        
        self.concurrentQueue.async {
            
            /// 文件管理
            let fileManager = FileManager.default
            /// 获取文件数组
            if let fileArray = fileManager.subpaths(atPath: self.path) {
                
                for file in fileArray {
                    
                    do {
                        /// 删除文件
                        try fileManager.removeItem(atPath: self.path + file)
                        
                    } catch  {
                        
                    }
                }
            }
        }
    }
    
    // MARK: - NetworkOperationDetegate
    
    func operation(_ key: String, received: Int64, expectedToReceive: Int64) {
        
        callbackProgress(key, current: received, total: expectedToReceive)
    }
    
    func operation(_ key: String, error: Error) {
        
        callbackResult(key, error: error, data: nil, path: nil)
        remove(key)
    }
    
    func operation(_ key: String, data: Data) {
        
        callbackResult(key, error: nil, data: data, path: nil)
        remove(key)
    }
    
    func operation(_ key: String, path: String) {
        
        callbackResult(key, error: nil, data: nil, path: path)
        remove(key)
    }
}

