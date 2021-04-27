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
open class Network: NetworkOperationDelegate {
    
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
    /// 回调与请求列表
    private var callbackRequest: [String: [String]] = [:]
    /// 最大并发数量
    open var maxConcurrent = Int.max { didSet { exceedMaxRunToWait(); nextRun() } }
    /// 磁盘文件夹路径
    open private(set) var path: String
    
    // MARK: - init
    
    /**
     初始化
     
     - parameter    name:       队列名称
     - parameter    max:        并发数
     - parameter    directory:  存储文件夹
     */
    public init(_ name: String, max: Int, directory: String) {
        
        concurrentQueue = DispatchQueue.init(label: name + ".concurrent", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
        serialQueue = DispatchQueue.init(label: name + ".serial")
        maxConcurrent = max
        path = directory
        
        createDirectory()
    }
    
    private convenience init() {
        
        self.init("Network", max: Int.max, directory: NSHomeDirectory() + "/Documents/Network/")
    }
    
    // MARK: - Load
    
    /**
     加载
     
     - parameter    urlString:          地址字符串
     - parameter    isCache:            是否缓存
     - parameter    isDisk:             是否磁盘存储(存储磁盘则不缓存)
     - parameter    isStart:            是否立即开始
     - parameter    fileName:           磁盘存储名字(有值则等于`isDisk=true`)
     - parameter    sameKeyHandle:      同标识处理
     - parameter    callbackID:         回调ID(用于取消 progress、result)
     - parameter    progress:           进度  (当前字节,总字节)
     - parameter    result:             结果  (错误信息,数据(isDisk = false 有值),数据路径(isDisk = true 有值))
     */
    open func load(_ urlString: String,
                     isCache: Bool = false,
                     isDisk: Bool = false,
                     isStart: Bool = true,
                     fileName: String? = nil,
                     sameKeyHandle: NetworkOperation.SameKeyHandle = .ignore,
                     callbackID: String = "\(Date.init().timeIntervalSince1970)-\(arc4random())",
                     progress: @escaping NetworkCallbackProgress = { _,_ in },
                     result: @escaping NetworkCallbackResult) {

        if let url = URL.init(string: urlString) {
            
            load(url, isCache: isCache, isDisk: isDisk, isStart: isStart, sameKeyHandle: sameKeyHandle, callbackID: callbackID, progress: progress, result: result)
        }
        else {
            
            result(nil, nil, nil)
        }
    }
    
    /**
     加载
     
     - parameter    url:                地址
     - parameter    isCache:            是否缓存
     - parameter    isDisk:             是否磁盘存储(存储磁盘则不缓存)
     - parameter    isStart:            是否立即开始
     - parameter    fileName:           磁盘存储名字(有值则等于`isDisk=true`)
     - parameter    sameKeyHandle:      同标识处理
     - parameter    callbackID:         回调ID(用于取消 progress、result)
     - parameter    progress:           进度  (当前字节,总字节)
     - parameter    result:             结果  (错误信息,数据(isDisk = false 有值),数据路径(isDisk = true 有值))
     */
    open func load(_ url: URL,
                     isCache: Bool = false,
                     isDisk: Bool = false,
                     isStart: Bool = true,
                     fileName: String? = nil,
                     sameKeyHandle: NetworkOperation.SameKeyHandle = .ignore,
                     callbackID: String = "\(Date.init().timeIntervalSince1970)-\(arc4random())",
                     progress: @escaping NetworkCallbackProgress = { _,_ in },
                     result: @escaping NetworkCallbackResult) {

        load(URLRequest.init(url: url), isCache: isCache, isDisk: isDisk, isStart: isStart, sameKeyHandle: sameKeyHandle, callbackID: callbackID, progress: progress, result: result)
    }
    
    /**
     加载
     
     - parameter    request:            URL请求
     - parameter    isCache:            是否缓存
     - parameter    isDisk:             是否磁盘存储(存储磁盘则不缓存)
     - parameter    isStart:            是否立即开始
     - parameter    fileName:           磁盘存储名字(有值则等于`isDisk=true`)
     - parameter    sameKeyHandle:      同标识处理
     - parameter    callbackID:         回调ID(用于取消 progress、result)
     - parameter    progress:           进度  (当前字节,总字节)
     - parameter    result:             结果  (错误信息,数据(isDisk = false 有值),数据路径(isDisk = true 有值))
     */
    open func load(_ request: URLRequest,
                     isCache: Bool = false,
                     isDisk: Bool = false,
                     isStart: Bool = true,
                     fileName: String? = nil,
                     sameKeyHandle: NetworkOperation.SameKeyHandle = .ignore,
                     callbackID: String = "\(Date.init().timeIntervalSince1970)-\(arc4random())",
                     progress: @escaping NetworkCallbackProgress = { _,_ in },
                     result: @escaping NetworkCallbackResult) {
        
        if let key = NetworkOperation.key(request) {
            
            var savePath: String? = nil
            
            if let name = fileName {
                
                savePath = path + name
            }
            else if isDisk {
                
                savePath = path + key
            }
            
            let operation = NetworkOperation.init(key, sameKeyHandle: sameKeyHandle, request: request, isCache: isCache, path: savePath, delegate: self)
            
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
                    
                    switch operation.sameKeyHandle {
                    case .ignore:
                        return
                    case .replace:
                        if !run.isFinished {
                            run.cancel()
                        }
                    case .none:
                        break
                    }
                }
            }
            
            /// 从等待列表中删除
            _ = self.removeWait(operation.key, sameKeyHandle: [.ignore, .replace])
            
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
                    
                    switch operation.sameKeyHandle {
                    case .ignore:
                        return
                    case .replace:
                        if !run.isFinished {
                            run.cancel()
                        }
                    case .none:
                        break
                    }
                }
            }
            
            /// 是否已存在
            var isExist = false
            /// 删除列表
            var removeList: [NetworkOperation] = []
            
            for wait in self.waitList {
                
                if wait.key == operation.key {
                    
                    switch operation.sameKeyHandle {
                    case .ignore:
                        isExist = true
                    case .replace:
                        if wait.sameKeyHandle != .none {
                            removeList.append(wait)
                        }
                    case .none:
                        break
                    }
                }
            }
            
            for item in removeList {
                
                _ = self.removeWait(item.key, sameKeyHandle: [.ignore, .replace])
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
    open func remove(_ key: String) {
        
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
     从等待列表中删除
     */
    private func removeWait(_ key: String, sameKeyHandle: [NetworkOperation.SameKeyHandle]) -> Bool {
        
        for i in 0..<self.waitList.count {
            
            if self.waitList[i].key == key, sameKeyHandle.contains(self.waitList[i].sameKeyHandle) {
                
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
                    self.waitList.insert(NetworkOperation.init(last.key, sameKeyHandle: last.sameKeyHandle, request: last.request, path: last.path, delegate: self), at: 0)
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
            
            if self.callbackRequest[id] == nil {
                
                self.callbackRequest[id] = [key]
            }
            else {
                
                self.callbackRequest[id]?.append(key)
            }
            
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
                    
                    if let requestKeyList = self.callbackRequest.removeValue(forKey: id) {
                        
                        var list: [String] = []
                        
                        for item in requestKeyList {
                            
                            if item != key {
                                
                                list.append(item)
                            }
                        }
                        
                        if list.count != 0 {
                            
                            self.callbackRequest[id] = list
                        }
                    }
                }
            }
        }
    }
    
    /**
     删除回调
     
     - parameter    id:         回调ID    (外部调用需在 load() 时 设置)
     */
    open func removeCallback(_ id: String) {
        
        self.serialQueue.async {
            
            self.callback.removeValue(forKey: id)
            
            if let requestKeyList = self.callbackRequest.removeValue(forKey: id) {
                
                for key in requestKeyList {
                    
                    if let callbackIdList = self.requestCallback.removeValue(forKey: key) {
                        
                        var list: [String] = []
                        
                        for item in callbackIdList {
                            
                            if item != id {
                                
                                list.append(item)
                            }
                        }
                        
                        if list.count != 0 {
                            
                            self.requestCallback[key] = list
                        }
                    }
                }
            }
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
    open func removeDiskFile(_ key: String) {
        
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
    open func removeAllDiskFile() {
        
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
    
    open func operation(_ key: String, received: Int64, expectedToReceive: Int64) {
        
        callbackProgress(key, current: received, total: expectedToReceive)
    }
    
    open func operation(_ key: String, error: Error) {
        
        callbackResult(key, error: error, data: nil, path: nil)
        remove(key)
        nextRun()
    }
    
    open func operation(_ key: String, data: Data) {
        
        callbackResult(key, error: nil, data: data, path: nil)
        remove(key)
        nextRun()
    }
    
    open func operation(_ key: String, path: String) {
        
        callbackResult(key, error: nil, data: nil, path: path)
        remove(key)
        nextRun()
    }
}

