//
//  NetworkOperation.swift
//  NetworkTest
//
//  Created by 韦烽传 on 2019/4/20.
//  Copyright © 2019 韦烽传. All rights reserved.
//

import Foundation

/**
 网络操作
 */
open class NetworkOperation: Operation, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate {
    
    /**
     同标识处理
     */
    public enum SameKeyHandle {
        
        /// 忽略请求
        case ignore
        /// 替换原请求
        case replace
        /// 继续请求
        case none
    }
    
    /// 信号量
    public let dispatchSemaphore = DispatchSemaphore.init(value: 0)
    /// 标识
    public let key: String
    /// 同标识处理
    let sameKeyHandle: SameKeyHandle
    /// URL请求
    open var request: URLRequest
    /// 会话
    open var session: URLSession?
    /// 任务
    open var task: URLSessionTask?
    /// 协议
    open var delegate: NetworkOperationDelegate?
    /// 数据
    open var data = Data()
    /// 是否缓存
    open var isCache: Bool
    /// 保存地址
    open var path: String?
    /// 文件Handle
    private var fileHandle: FileHandle?
    
    // MARK: - key
    
    /**
     默认的标识
     
     - parameter    urlString:  地址字符串
     */
    public static func key(_ urlString: String) -> String? {
        
        if let url = URL.init(string: urlString) {
            
            return key(url)
        }
        
        return nil
    }
    
    /**
     默认的标识
     
     - parameter    url:        地址
     */
    public static func key(_ url: URL) -> String? {
        
        return key(URLRequest.init(url: url))
    }
    
    /**
     默认的标识
     
     - parameter    request:    请求
     */
    public static func key(_ request: URLRequest) -> String? {
        
        if let url = request.url, let data = url.absoluteString.data(using: .utf8) {
            
            return data.base64EncodedString()
        }
        
        return nil
    }
    
    // MARK: - init
    
    /**
     初始化
     
     - parameter    key:                标识
     - parameter    sameKeyHandle:      同标识处理
     - parameter    request:            请求
     - parameter    isCache:            是否缓存
     - parameter    path:               磁盘路径(如果 path != nil 则 存储磁盘，并且不缓存数据)
     - parameter    delegate:           网络操作协议
     */
    public init(_ key: String, sameKeyHandle: SameKeyHandle, request: URLRequest, isCache: Bool = false, path: String? = nil, delegate: NetworkOperationDelegate? = nil) {
        
        self.key = key
        self.sameKeyHandle = sameKeyHandle
        self.request = request
        self.isCache = isCache
        self.path = path
        self.delegate = delegate
    }
    
    /**
     操作主体，isExecuting/isFinished 是 main() 的状态
     */
    override open func main() {
        
        /// 断点下载
        if let path = self.path {
            
            /// 文件大小
            var fileSize = 0
            
            let fm = FileManager.default
            
            /// 文件是否存在
            if fm.fileExists(atPath: path) {
                
                delegate?.operation(key, received: 1, expectedToReceive: 1)
                delegate?.operation(key, path: path)
                return
            }
            
            /// 缓存路径
            let cachePath = path + ".cache"
            
            /// 缓存文件是否存在
            if !fm.fileExists(atPath: cachePath) {
                
                /// 创建文件
                fm.createFile(atPath: cachePath, contents: Data.init(), attributes: nil)
            }
            
            do {
                /// 获取文件属性
                let attributes = try fm.attributesOfItem(atPath: cachePath)
                fileSize = (attributes[FileAttributeKey.size] as? Int) ?? 0
            } catch  {
                delegate?.operation(key, error: error)
                return
            }
            
            do {
                fileHandle = try FileHandle.init(forUpdating: URL.init(fileURLWithPath: cachePath))
            } catch  {
                delegate?.operation(key, error: error)
                return
            }
            
            if fileSize > 0 {
                
                /// 设置下载偏移
                request.setValue("bytes=\(fileSize)-", forHTTPHeaderField: "Range")
            }
        }
        else if isCache {
            
            if let dataCache = DataCache.default.get(key) {
                
                delegate?.operation(key, received: 1, expectedToReceive: 1)
                delegate?.operation(key, data: dataCache)
                return
            }
        }
        
        session = URLSession.init(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        task = session?.dataTask(with: request)
        task?.resume()
        
        /// 等待下载完成/出错
        dispatchSemaphore.wait()
        
        /// 清除
        delegate = nil
        session?.invalidateAndCancel()
        session = nil
        task?.cancel()
        task = nil
    }
    
    override open func cancel() {
        super.cancel()
        
        if !isCancelled {
            
            dispatchSemaphore.signal()
        }
    }
    
    // MARK: - URLSessionDelegate
    
    /**
     失效
     */
    open func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        
    }
    
    /**
     收到权限认证
     */
    open func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        /// 处理
        completionHandler(.performDefaultHandling, challenge.proposedCredential)
    }
    
    /**
     后台下载完成
     */
    #if os(iOS) || os(watchOS) || os(tvOS)
    open func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        
    }
    #endif
    
    // MARK: - URLSessionTaskDelegate
    
    /*
    /**
     将开始延时请求
     */
    func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
        
        /// 处理
        completionHandler(.continueLoading, request)
    }
    
    /**
     等待连接
     */
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        
    }
    */
    
    /**
     已发送数据的大小
     */
    open func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
    }
    
    /**
     收到权限认证
     */
    open func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        /// 处理
        completionHandler(.performDefaultHandling, challenge.proposedCredential)
    }
    
    /**
     将重定向请求
     */
    open func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        
        completionHandler(request)
    }
    
    /**
     需要新的流
     */
    open func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        
        completionHandler(nil)
    }
    
    /**
     完成收集
     */
    @available(iOS 10.0, *)
    open func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        
    }
    
    /**
     完成/错误
     */
    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        if let e = error {
            
            delegate?.operation(key, error: e)
        }
        else if let path = self.path {
            
            do {
                
                try FileManager.default.moveItem(atPath: path + ".cache", toPath: path)
                delegate?.operation(key, path: path)
                
            } catch {
                
                delegate?.operation(key, error: error)
            }
        }
        else {
            
            if isCache {
                
                DataCache.default.add(key, data: data)
            }
            
            delegate?.operation(key, data: data)
        }
        
        dispatchSemaphore.signal()
    }
    
    // MARK: - URLSessionDataDelegate
    
    /**
     收到响应
     */
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        /// 是否支持断点下载
        if let httpResponse = response as? HTTPURLResponse, httpResponse.allHeaderFields["Accept-Ranges"] != nil || httpResponse.allHeaderFields["Content-Range"] != nil {
            
        }
        else {
            
            /// 清空缓存文件
            fileHandle?.truncateFile(atOffset: 0)
            fileHandle?.synchronizeFile()
        }
        
        delegate?.operation(key, received: dataTask.countOfBytesReceived, expectedToReceive: dataTask.countOfBytesExpectedToReceive)
        
        /// 处理
        completionHandler(.allow)
    }
    
    /**
     收到数据
     */
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        if path == nil {
            
            self.data.append(data)
        }
        else {
            
            fileHandle?.seekToEndOfFile()
            fileHandle?.write(data)
            fileHandle?.synchronizeFile()
        }
        
        delegate?.operation(key, received: dataTask.countOfBytesReceived, expectedToReceive: dataTask.countOfBytesExpectedToReceive)
    }
    
    /**
     开始下载任务
     */
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        
    }
    
    /**
     开始流任务
     */
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
        
    }
    
    /**
     将缓存响应
     */
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        
        /// 处理
        completionHandler(proposedResponse)
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    /**
     下载进度
     */
    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
    }
    
    /**
     下载完成
     */
    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
    }
    
    /**
     下载偏移
     */
    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        
    }
}
