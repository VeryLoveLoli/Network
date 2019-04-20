//
//  Network.swift
//  NetworkTest
//
//  Created by 韦烽传 on 2019/4/19.
//  Copyright © 2019 韦烽传. All rights reserved.
//

import Foundation

/// 进度回调
public typealias CallbackProgress = (Int64, Int64)->Void
/// 结果回调
public typealias CallbackResult = (Error?, Data?, String?)->Void
/// 回调
public typealias Callback = (CallbackProgress, CallbackResult)

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
    private var callback: [String: Callback] = [:]
    /// 最大并发数量
    var maxConcurrent = Int.max
    /// 磁盘文件夹路径
    var path: String
    
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
                     progress: @escaping CallbackProgress = { _,_ in },
                     result: @escaping CallbackResult) {

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
                     progress: @escaping CallbackProgress = { _,_ in },
                     result: @escaping CallbackResult) {

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
                     progress: @escaping CallbackProgress = { _,_ in },
                     result: @escaping CallbackResult) {
        
        if let url = request.url, let data = url.absoluteString.data(using: .utf8) {
            
            let key = data.base64EncodedString()
            
            let operation = NetworkOperation.init(key, request: request, path: isDisk ? (path + key) : nil)
            operation.delegate = self
            
            addCallback(key, id: callbackID, callback: (progress, result))

            if isStart {
                
                addRun(operation)
            }
            else {
                
                addWait(operation)
            }
        }
    }
    
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
            
            /// 将过多的运行放入等待列表
            while self.runList.count > self.maxConcurrent && self.runList.count > 1 {
                
                let last = self.runList.remove(at: self.runList.count - 1)
                
                if !last.isFinished {
                    
                    last.cancel()
                    self.waitList.insert(NetworkOperation.init(last.key, request: last.request, path: last.path), at: 0)
                }
            }
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
            
            /// 从等待列表中删除
            _ = self.removeWait(operation.key)
            
            /// 加入等待列表
            self.waitList.insert(operation, at: 0)
        }
        
        nextRun()
    }
    
    /**
     删除
     */
    public func remove(_ key: String) {
        
        self.serialQueue.async {
            
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
                
                self.waitList[i].cancel()
                self.waitList.remove(at: i)
                
                return true
            }
        }
        
        return false
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
    
    /**
     添加回调
     
     - parameter    key:        操作标识
     - parameter    id:         回调ID
     - parameter    callback:   回调
     */
    private func addCallback(_ key: String, id: String, callback: Callback) {
        
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
     
     - parameter    id:         回调ID
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
    
    // MARK: - NetworkOperationDetegate
    
    func operation(_ key: String, received: Int64, expectedToReceive: Int64) {
        
        callbackProgress(key, current: received, total: expectedToReceive)
    }
    
    func operation(_ key: String, error: Error) {
        
        _ = removeRun(key)
        callbackResult(key, error: error, data: nil, path: nil)
        removeRequestCallback(key)
    }
    
    func operation(_ key: String, data: Data) {
        
        _ = removeRun(key)
        nextRun()
        callbackResult(key, error: nil, data: data, path: nil)
        removeRequestCallback(key)
    }
    
    func operation(_ key: String, path: String) {
        
        _ = removeRun(key)
        nextRun()
        callbackResult(key, error: nil, data: nil, path: path)
        removeRequestCallback(key)
    }
}

