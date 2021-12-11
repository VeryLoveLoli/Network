//
//  Network.swift
//  
//
//  Created by 韦烽传 on 2019/4/19.
//  Copyright © 2019 韦烽传. All rights reserved.
//

import Foundation
import CommonCrypto

/**
 网络
 */
open class Network {
    
    // MARK: - Parameter
    
    /// 默认
    public static let `default` = Network(configuration: URLSessionConfiguration.default, path: NSHomeDirectory() + "/Documents/Network/")
    /// 文件夹
    public static var folder = "Data/"
    
    /// 会话
    public let session: URLSession
    /// 会话协议
    let sessionDelegate: Network.SessionDelegate
    
    /// 存储路径
    public let path: String
    
    // MARK: - init
    
    /**
     初始化
     
     - parameter    configuration:  网络配置
     - parameter    queue:          网络任务队列
     - parameter    path:           存储路径
     */
    public init(configuration: URLSessionConfiguration, queue: OperationQueue? = nil, path: String) {
        
        self.path = path
        sessionDelegate = Network.SessionDelegate(path: path)
        session = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: queue)
        
        createDirectory(path + Network.folder)
        createDirectory(path + Network.DiskCache.folder)
    }
    
    // MARK: - Load
    
    /**
     加载数据
     
     - parameter    request:            URL请求
     - parameter    callbackKey:        回调标识
     - parameter    data:               成功数据
     - parameter    error:              失败错误
     */
    open func data(_ request: URLRequest,
                   callbackKey: String = "\(Date.init().timeIntervalSince1970)-\(arc4random())",
                   data: @escaping ((Data)->Void),
                   error: @escaping ((Error)->Void)) {
        
        if let key = Network.key(request) {
            
            load(request, key: key, callbackKey: callbackKey, cachePolicy: .reload, data: data, path: nil, progress: nil, error: error)
        }
        else {
            
            error(Network.MessageError("URLRequest.url is nil"))
        }
    }
    
    /**
     下载
     
     - parameter    request:            URL请求
     - parameter    callbackKey:        回调标识
     - parameter    path:               成功文件路径
     - parameter    progress:           进度  (当前字节,总字节)
     - parameter    error:              失败错误
     */
    open func download(_ request: URLRequest,
                       callbackKey: String = "\(Date.init().timeIntervalSince1970)-\(arc4random())",
                       cachePolicy: Network.CachePolicy = .cache,
                       path: @escaping ((String)->Void),
                       progress: @escaping ((Int64, Int64)->Void),
                       error: @escaping ((Error)->Void)) {
        
        if let key = Network.key(request) {
            
            load(request, key: key, callbackKey: callbackKey, cachePolicy: cachePolicy, data: nil, path: path, progress: progress, error: error)
        }
        else {
            
            error(Network.MessageError("URLRequest.url is nil"))
        }
    }
    
    /**
     加载
     
     - parameter    request:            URL请求
     - parameter    key:                请求标识（默认使用`Network.key()`）
     - parameter    callbackKey:        回调标识
     - parameter    cachePolicy:        缓存策略（需实现`path:`回调）
     - parameter    data:               成功数据
     - parameter    path:               成功文件路径
     - parameter    progress:           进度  (当前字节,总字节)
     - parameter    error:              失败错误
     
     注意：
     1. 4个闭包至少设置一个
     2. 同一`key`请求标识的请求，`data`和`path`闭包是否有值需设置相同，不然会导致数据不完整
     */
    open func load(_ request: URLRequest,
                   key: String,
                   callbackKey: String,
                   cachePolicy: Network.CachePolicy,
                   data: ((Data)->Void)? = nil,
                   path: ((String)->Void)? = nil,
                   progress: ((Int64, Int64)->Void)? = nil,
                   error: ((Error)->Void)? = nil) {
        
        /// 是否已有请求
        let isRequest = sessionDelegate.dataCallback.isRequest(key)
        || sessionDelegate.pathCallback.isRequest(key)
        || sessionDelegate.progressCallback.isRequest(key)
        || sessionDelegate.errorCallback.isRequest(key)
        
        /**
         有下载完成文件 回调路径和数据
         */
        
        /// 磁盘路径
        let diskPath = sessionDelegate.diskCache.path + Network.folder + key
        
        /// 下载完成文件是否存在
        if FileManager.default.fileExists(atPath: diskPath) && (cachePolicy == .cache || cachePolicy == .cacheAndReload) {
            
            if let callback = data {
                
                let errorCallback = error
                
                DispatchQueue.global().async {
                    
                    do {
                        
                        let diskData = try Data(contentsOf: URL(fileURLWithPath: diskPath))
                        
                        callback(diskData)
                        progress?(1,1)
                        
                    } catch {
                        
                        errorCallback?(error)
                    }
                }
            }
            
            if let callback = path {
                
                DispatchQueue.global().async {
                    
                    callback(diskPath)
                    progress?(1,1)
                }
            }
            
            if cachePolicy == .cache {
                
                /// 退出
                
                return
            }
        }
        
        /**
         添加回调
         */
        
        if let callback = data {
            
            sessionDelegate.dataCallback.add(key: key, callbackKey: callbackKey, callback: callback)
        }
        
        if let callback = path {
            
            sessionDelegate.pathCallback.add(key: key, callbackKey: callbackKey, callback: callback)
        }
        
        if let callback = progress {
            
            sessionDelegate.progressCallback.add(key: key, callbackKey: callbackKey, callback: callback)
        }
        
        if let callback = error {
            
            sessionDelegate.errorCallback.add(key: key, callbackKey: callbackKey, callback: callback)
        }
        
        /// 请求任务已存在 退出
        if isRequest { return }
        
        /**
         添加文件处理
         */
        
        var req = request
        
        if path != nil {
            
            /// 磁盘缓存路径
            let cachePath = sessionDelegate.diskCache.path + Network.DiskCache.folder + key + Network.DiskCache.fileType
            
            /// 缓存文件是否存在
            if !FileManager.default.fileExists(atPath: cachePath) {
                
                /// 创建文件
                FileManager.default.createFile(atPath: cachePath, contents: Data.init(), attributes: nil)
            }
            
            let errorCallback = error
            
            do {
                /// 获取文件属性
                let attributes = try FileManager.default.attributesOfItem(atPath: cachePath)
                /// 文件大小
                let fileSize = (attributes[FileAttributeKey.size] as? Int) ?? 0
                
                if fileSize > 0 {
                    
                    /// 设置下载偏移
                    req.setValue("bytes=\(fileSize)-", forHTTPHeaderField: "Range")
                }
                
                /// 创建文件处理
                let fileHandle = try FileHandle.init(forUpdating: URL.init(fileURLWithPath: cachePath))
                sessionDelegate.diskCache.add(key: key, value: fileHandle)
                
            } catch {
                
                /// 回调错误
                errorCallback?(error)
                
                /// 删除回调
                sessionDelegate.dataCallback.remove(key: key)
                sessionDelegate.pathCallback.remove(key: key)
                sessionDelegate.progressCallback.remove(key: key)
                sessionDelegate.errorCallback.remove(key: key)
                
                /// 退出
                
                return
            }
        }
        
        /**
         添加任务
         */
        
        let task = session.dataTask(with: req)
        
        task.taskDescription = key
        
        task.resume()
    }
    
    // MARK: - Task
    
    /**
     获取任务
     
     - parameter    key:                请求标识（默认使用`Network.key()`）
     - parameter    completionHandler:  回调任务
     */
    open func task(_ key: String, completionHandler: @escaping (URLSessionTask) -> Void) {
        
        session.getAllTasks { items in
            
            for item in items {
                
                if item.taskDescription == key {
                    
                    completionHandler(item)
                    break
                }
            }
        }
    }
    
    /**
     获取任务
     
     - parameter    key:                请求标识（默认使用`Network.key()`）
     
     - returns  任务
     */
    @available(iOS 15.0.0, *)
    open func task(_ key: String) async -> URLSessionTask? {
        
        for item in await session.allTasks {
            
            if item.taskDescription == key {
                
                return item
            }
        }
        
        return nil
    }
}

/**
 网络错误
 */
public extension Network {
    
    /**
     消息错误
     */
    class MessageError: Error {
        
        /// 错误消息
        let message: String
        
        /// 本地描述
        public var localizedDescription: String { message }
        
        /**
         初始化
         
         - parameter    string:     信息
         */
        init(_ string: String) {
            
            message = string
        }
    }
}

/**
 网络文件夹
 */
public extension Network {
    
    // MARK: - FileManager
    
    /**
     创建文件夹
     */
    @discardableResult
    func createDirectory(_ path: String) -> Bool {
        
        /// 文件管理
        let fileManager: FileManager = FileManager.default
        
        /// 判断文件夹是否存在
        if !fileManager.fileExists(atPath: path) {
            
            do {
                /// 创建文件夹
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                
            } catch {
                
                return false
            }
        }
        
        return true
    }
    
    /**
     删除磁盘下载完成文件
     
     - parameter    key:        操作标识    (外部调用需通过 `Network.key()` 获取 )
     */
    @discardableResult
    func removeDiskFile(key: String) -> Bool {
        
        return removeDiskFile(path + Network.folder + key)
    }
    
    /**
     删除磁盘下载缓存文件
     
     - parameter    key:        操作标识    (外部调用需通过 `Network.key()` 获取 )
     */
    @discardableResult
    func removeDiskCacheFile(key: String) -> Bool {
        
        return removeDiskFile(path + Network.DiskCache.folder + key + Network.DiskCache.fileType)
    }
    
    /**
     删除磁盘所有下载完成文件
     */
    func removeDiskAllFile() {
        
        removeDiskFolderFiles(path + Network.folder)
    }
    
    /**
     删除磁盘所有下载缓存文件
     */
    func removeDiskCacheAllFiel() {
        
        removeDiskFolderFiles(path + Network.DiskCache.folder)
    }
    
    /**
     删除磁盘文件
     
     - parameter    path:       文件路径
     */
    @discardableResult
    func removeDiskFile(_ path: String) -> Bool {
        
        /// 文件管理
        let fileManager = FileManager.default
        
        /// 判断文件是否存在
        if fileManager.fileExists(atPath: path) {
            
            do {
                /// 删除文件
                try fileManager.removeItem(atPath: path)
                
            } catch  {
                
                return false
            }
        }
        
        return true
    }
    
    /**
     删除磁盘文件夹文件
     
     - parameter    path:       文件夹路径
     */
    func removeDiskFolderFiles(_ path: String) {
        
        /// 文件管理
        let fileManager = FileManager.default
        /// 获取文件数组
        if let fileArray = fileManager.subpaths(atPath: path) {
            
            for file in fileArray {
                
                do {
                    /// 删除文件
                    try fileManager.removeItem(atPath: path + file)
                    
                } catch  {
                    
                }
            }
        }
    }
}

/**
 网络缓存策略
 */
public extension Network {
    
    /**
     缓存策略
     */
    enum CachePolicy {
        
        /// 重新加载（直接加载忽略缓存）
        case reload
        /// 使用缓存（有缓存回调缓存，无缓存加载）
        case cache
        /// 使用缓存并重新加载（有缓存则回调缓存并重新加载，两次回调；无缓存加载）
        case cacheAndReload
    }
}

/**
 网络文件存储
 */
public extension Network {
    
    /**
     磁盘缓存
     */
    class DiskCache {
        
        // MARK: - Parameter
        
        /// 文件处理字典
        var dictionary: [String: FileHandle] = [:]
        
        /// 信号
        var semaphore = DispatchSemaphore(value: 1)
        
        /// 文件路径
        let path: String
        /// 文件夹
        public static var folder = "Cache/"
        /// 文件类型
        public static var fileType = ".cache"
        
        // MARK: - init
        
        /**
         初始化
         */
        init(path: String) {
            
            self.path = path
        }
        
        // MARK: - Event
        
        /**
         添加
         */
        func add(key: String, value: FileHandle) {
            
            semaphore.wait()
            
            if dictionary[key] == nil {
                
                dictionary[key] = value
            }
            
            semaphore.signal()
        }
        
        /**
         写数据
         */
        func write(key: String, data: Data) {
            
            semaphore.wait()
            
            dictionary[key]?.seekToEndOfFile()
            dictionary[key]?.write(data)
            dictionary[key]?.synchronizeFile()
            
            semaphore.signal()
        }
        
        /**
         清除缓存（截断文件到`0 bytes`）
         */
        func clean(key: String) {
            
            semaphore.wait()
            
            dictionary[key]?.truncateFile(atOffset: 0)
            dictionary[key]?.synchronizeFile()
            
            semaphore.signal()
        }
        
        /**
         删除
         */
        func remove(key: String) {
            
            semaphore.wait()
            
            dictionary.removeValue(forKey: key)
            
            semaphore.signal()
        }
        
        /**
         删除所有
         */
        func removeAll() {
            
            semaphore.wait()
            
            dictionary.removeAll()
            
            semaphore.signal()
        }
    }
}

/**
 网络数据缓存
 */
public extension Network {
    
    /**
     数据缓存
     */
    class DataCache {
        
        // MARK: - Parameter
        
        /// 缓存字典
        var dictionary: [String: Data] = [:]
        
        /// 信号
        var semaphore = DispatchSemaphore(value: 1)
        
        // MARK: - Event
        
        /**
         添加数据
         */
        func append(key: String, value: Data) {
            
            semaphore.wait()
            
            if dictionary[key] != nil {
                
                dictionary[key]?.append(value)
            }
            else {
                
                dictionary[key] = value
            }
            
            semaphore.signal()
        }
        
        /**
         获取数据
         */
        func data(key: String) -> Data? {
            
            var data: Data?
            
            semaphore.wait()
            
            data = dictionary[key]
            
            semaphore.signal()
            
            return data
        }
        
        /**
         删除
         */
        func remove(key: String) {
            
            semaphore.wait()
            
            dictionary.removeValue(forKey: key)
            
            semaphore.signal()
        }
        
        /**
         删除所有
         */
        func removeAll() {
            
            semaphore.wait()
            
            dictionary.removeAll()
            
            semaphore.signal()
        }
    }
}

/**
 网络会话协议回调
 */
public extension Network {
    
    /**
     会话协议回调
     */
    class SessionDelegate: NSObject, URLSessionDataDelegate {
        
        // MARK: - Parameter
        
        /// 数据回调
        let dataCallback = Network.Callback<Data>()
        /// 路径回调
        let pathCallback = Network.Callback<String>()
        /// 错误回调
        let errorCallback = Network.Callback<Error>()
        /// 进度回调
        let progressCallback = Network.Callback<(Int64, Int64)>()
        
        /// 数据缓存
        let dataCache = Network.DataCache()
        /// 磁盘缓存
        let diskCache: Network.DiskCache
        
        /// 认证
        open var authChallenge: ((URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?))? = nil
        /// 任务认证
        open var taskAuthChallenge: ((URLSessionTask, URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?))? = nil
        
        // MARK: - init
        
        /**
         初始化
         */
        init(path: String) {
            
            diskCache = Network.DiskCache(path: path)
        }
        
        // MARK: - URLSessionDelegate
        
        /**
         失效
         */
        public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
            
            dataCallback.removeAll()
            pathCallback.removeAll()
            
            if let error = error {
                
                errorCallback.callbackAll(any: error)
            }
            else {
                
                errorCallback.removeAll()
            }
            
            progressCallback.removeAll()
            
            dataCache.removeAll()
            diskCache.removeAll()
        }
        
        /**
         收到权限认证
         */
        public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            
            if let (a, c) = authChallenge?(challenge) {
                
                completionHandler(a, c)
            }
            else {
                
                completionHandler(.performDefaultHandling, challenge.proposedCredential)
            }
        }
        
        // MARK: - URLSessionTaskDelegate
        
        /**
         收到权限认证
         */
        public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            
            if let (a, c) = taskAuthChallenge?(task, challenge) {
                
                completionHandler(a, c)
            }
            else {
                
                completionHandler(.performDefaultHandling, challenge.proposedCredential)
            }
        }
        
        /**
         需要新的流
         */
        public func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
            
            completionHandler(nil)
        }
        
        /**
         完成/错误
         */
        public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            
            guard let key = task.taskDescription else { return }
            
            if let error = error {
                
                dataCallback.remove(key: key)
                pathCallback.remove(key: key)
                errorCallback.callback(key: key, any: error)
                progressCallback.remove(key: key)
            }
            else {
                
                if dataCallback.isRequest(key) {
                    
                    dataCallback.callback(key: key, any: dataCache.data(key: key) ?? Data())
                }
                
                if pathCallback.isRequest(key) {
                    
                    do {
                        
                        /// 磁盘缓存路径
                        let cachePath = diskCache.path + Network.DiskCache.folder + key + Network.DiskCache.fileType
                        /// 文件路径
                        let filePath = diskCache.path + Network.folder + key
                        
                        try FileManager.default.moveItem(atPath: cachePath, toPath: filePath)
                        
                        pathCallback.callback(key: key, any: filePath)
                        
                    } catch {
                        
                        pathCallback.remove(key: key)
                        errorCallback.callback(key: key, any: error)
                    }
                }
                
                errorCallback.remove(key: key)
                progressCallback.remove(key: key)
            }
            
            dataCache.remove(key: key)
            diskCache.remove(key: key)
        }
        
        // MARK: - URLSessionDataDelegate
        
        /**
         收到响应
         */
        public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            
            guard let key = dataTask.taskDescription else { completionHandler(.allow); return }
            
            /// 是否支持断点下载
            if let httpResponse = response as? HTTPURLResponse, httpResponse.allHeaderFields["Accept-Ranges"] != nil || httpResponse.allHeaderFields["Content-Range"] != nil {
                
            }
            else {
                
                diskCache.clean(key: key)
            }
            
            progressCallback.callback(key: key, any: (dataTask.countOfBytesReceived, dataTask.countOfBytesExpectedToReceive))
            
            completionHandler(.allow)
        }
        
        /**
         收到数据
         */
        public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            
            guard let key = dataTask.taskDescription else { return }
            
            if dataCallback.isRequest(key) {
                
                dataCache.append(key: key, value: data)
            }
            
            if pathCallback.isRequest(key) {
                
                diskCache.write(key: key, data: data)
            }
            
            progressCallback.callback(key: key, any: (dataTask.countOfBytesReceived, dataTask.countOfBytesExpectedToReceive))
        }
        
        /**
         将缓存响应
         */
        public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
            
            completionHandler(proposedResponse)
        }
    }
}

/**
 网络回调
 */
public extension Network {
    
    /**
     回调
     T: 回调类型
     */
    class Callback<T> {
        
        // MARK: - Parameter
        
        /// 回调字典
        var dictionary: [String: [String : (T)->Void]] = [:]
        
        /// 信号
        var semaphore = DispatchSemaphore(value: 1)
        
        // MARK: - Callback
        
        /**
         添加回调
         
         - parameter    key:            请求标识
         - parameter    callbackKey:    回调标识
         - parameter    callback:       回调
         */
        func add(key: String, callbackKey: String, callback: @escaping (T)->Void) {
            
            semaphore.wait()
            
            if dictionary[key] != nil {
                
                dictionary[key]?[callbackKey] = callback
            }
            else {
                
                dictionary[key] = [callbackKey: callback]
            }
            
            semaphore.signal()
        }
        
        /**
         删除回调
         
         - parameter    key:            请求标识
         - parameter    callbackKey:    回调标识
         */
        func remove(key: String, callbackKey: String) {
            
            semaphore.wait()
            
            dictionary[key]?.removeValue(forKey: callbackKey)
            
            if let dict = dictionary[key], dict.count == 0 {
                
                dictionary.removeValue(forKey: key)
            }
            
            semaphore.signal()
        }
        
        /**
         删除回调
            
         - parameter    callbackKey:    回调标识
         */
        func remove(callbackKey: String) {
            
            semaphore.wait()
            
            for key in dictionary.keys {
                
                dictionary[key]?.removeValue(forKey: callbackKey)
                
                if let dict = dictionary[key], dict.count == 0 {
                    
                    dictionary.removeValue(forKey: key)
                }
            }
            
            semaphore.signal()
        }
        
        /**
         删除回调
         
         - parameter    key:            请求标识
         */
        func remove(key: String) {
            
            semaphore.wait()
            
            dictionary.removeValue(forKey: key)
            
            semaphore.signal()
        }
        
        /**
         删除所有
         */
        func removeAll() {
            
            semaphore.wait()
            
            dictionary.removeAll()
            
            semaphore.signal()
        }
        
        /**
         是否请求中
         
         - parameter    key:            请求标识
         */
        func isRequest(_ key: String) -> Bool {
            
            var bool = false
            
            semaphore.wait()
            
            if let dict = dictionary[key] {
                
                if dict.count > 0 {
                    
                    bool = true
                }
                else {
                    
                    dictionary.removeValue(forKey: key)
                }
            }
            
            semaphore.signal()
            
            return bool
        }
        
        /**
         回调结果
         
         - parameter    key:            请求标识
         - parameter    any:            回调结果
         - parameter    isRemove:       是否删除回调
         */
        func callback(key: String , any: T, isRemove: Bool = true) {
            
            semaphore.wait()
            
            if let dict = dictionary[key] {
                
                for (_, v) in dict {
                    
                    /// 防止卡住异步处理
                    DispatchQueue.global().async {
                        
                        v(any)
                    }
                }
            }
            
            if isRemove {
                
                dictionary.removeValue(forKey: key)
            }
            
            semaphore.signal()
        }
        
        /**
         回调所有结果
         
         - parameter    any:            回调结果
         - parameter    isRemove:       是否删除回调
         */
        func callbackAll(any: T, isRemove: Bool = true) {
            
            semaphore.wait()
            
            for (_, item) in dictionary {
                
                for (_, v) in item {
                    
                    /// 防止卡住异步处理
                    DispatchQueue.global().async {
                        
                        v(any)
                    }
                }
            }
            
            if isRemove {
                
                dictionary.removeAll()
            }
            
            semaphore.signal()
        }
    }
}

/**
 网络标识
 */
public extension Network {
    
    // MARK: - key
    
    /**
     默认的标识
     
     - parameter    urlString:  地址字符串
     */
    static func key(_ urlString: String) -> String? {
        
        if let url = URL.init(string: urlString) {
            
            return key(url)
        }
        
        return nil
    }
    
    /**
     默认的标识
     
     - parameter    url:        地址
     */
    static func key(_ url: URL) -> String? {
        
        return key(URLRequest.init(url: url))
    }
    
    /**
     默认的标识
     
     - parameter    request:    请求
     */
    static func key(_ request: URLRequest) -> String? {
        
        if let urlData = request.url?.absoluteString.data(using: .utf8) {
            
            var bytes = [UInt8](urlData)
            
            if let body = request.httpBody {
                
                bytes += [UInt8](body)
            }
            
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256(&bytes, CC_LONG(bytes.count), &digest)
            
            let string = digest.reduce("") { $0 + String(format:"%02x", $1)}
            
            return string
        }
        
        return nil
    }
}
