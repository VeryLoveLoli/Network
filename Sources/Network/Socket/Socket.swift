//
//  Socket.swift
//  
//
//  Created by 韦烽传 on 2019/4/21.
//  Copyright © 2019 韦烽传. All rights reserved.
//

import Foundation

/// Socket 回调参数   (地址,字节,读取状态)
public typealias SocketCallbackParames = (Address, [UInt8], Int)
/// Socket 回调
public typealias SocketCallback = (SocketCallbackParames)->Void

/**
 Socket
 */
open class Socket {
    
    /**
     连接类型
     */
    public enum ConnectType {
        
        /// TCP
        case tcp
        /// UDP
        case udp
    }
    
    /// 端口
    open private(set) var port: UInt16
    /// 连接类型
    public let type: Socket.ConnectType
    /// Socket句柄
    open private(set) var id: Int32
    /// 连接状态
    open var status: Int32 { return fcntl(id, F_GETFL, 0)}
    /// 发送串行队列
    internal let sendSerialQueue: DispatchQueue
    /// 读取串行队列
    internal let recvSerialQueue: DispatchQueue
    /// 回调字典
    internal var callback = Socket.Callback<SocketCallbackParames>()
    
    // MARK: - init
    
    /**
     创建 Socket
     
     - parameter    port:       端口
     - parameter    type:       连接类型
     */
    internal static func `default`(_ port: UInt16, type: Socket.ConnectType) -> Self? {
        
        var id: Int32 = -1
        switch type {
        case .tcp:
            id = socket(AF_INET, SOCK_STREAM, 0)
        case .udp:
            id = socket(AF_INET, SOCK_DGRAM, 0)
        }
        
        if id == -1 {
            
            return nil
        }
        
        return self.init(id, port: port, type: type)
    }
    
    /**
     初始化 Socket
     
     - parameter    id:         socket
     - parameter    port:       端口
     - parameter    type:       连接类型
     */
    public required init(_ id: Int32, port: UInt16, type: Socket.ConnectType) {
        
        self.port = port
        self.type = type
        self.id = id
        
        let key = "\(Date.init().timeIntervalSince1970)-\(arc4random())"
        sendSerialQueue = DispatchQueue.init(label: "\(key).send.\(type).scoket.serial")
        recvSerialQueue = DispatchQueue.init(label: "\(key).recv.\(type).scoket.serial")
    }
    
    /**
     取消
     */
    open func cancel() {
        
        if status != -1 {
            
            var address: Address
            
            switch type {
            case .tcp:
                address = Address.init(peername: id)
            default:
                address = Address.init(sockname: id)
            }
            
            broadcastCallback(address, bytes: [], code: 0)
            
            close(id)
            
            removeAllCallback()
        }
    }
    
    // MARK: - socket
    
    /**
     绑定
     */
    open func bindAddress() -> Int32 {
        
        var addr = Address.init("127.0.0.1", port: port).sockaddrStruct()
        
        /// 绑定
        let status = bind(id, &(addr), UInt32(MemoryLayout.stride(ofValue: addr)))

        if status == 0 {
            
            if port == 0 {
                
                /// 更新绑定端口
                port = Address.init(sockname: id).port
            }
        }
        
        return status
    }
    
    /**
     缓冲
     
     - parameter    rcvbuf:     读取缓冲
     - parameter    sndbuf:     发送缓冲
     */
    open func socketBuf(_ rcvbuf: UInt32 = 1024*1024, sndbuf: UInt32 = 1024*1024) {
        
        /// 读取缓冲
        var RCVBUF = rcvbuf
        setsockopt(id, SOL_SOCKET, SO_RCVBUF, &RCVBUF, UInt32(MemoryLayout.stride(ofValue: RCVBUF)))
        /// 发送缓冲
        var SNDBUF = sndbuf
        setsockopt(id, SOL_SOCKET, SO_SNDBUF, &SNDBUF, UInt32(MemoryLayout.stride(ofValue: SNDBUF)))
    }
    
    // MARK: - Callback
    
    /**
     添加回调
     
     - parameter    key:        标识
     - parameter    callback:   Socket 回调   (地址,字节,读取状态)
     */
    open func addCallback(_ key: String, callback: @escaping SocketCallback) {
        
        self.callback.add(key, callback: callback)
    }
    
    /**
     删除回调
     
     - parameter    key:        标识
     */
    open func removeCallback(_ key: String) {
        
        callback.remove(key)
    }
    
    /**
     删除所有回调
     
     */
    open func removeAllCallback() {
        
        callback.removeAll()
    }
    
    /**
     广播回调
     
     - parameter    address:    地址
     - parameter    bytes:      数据
     - parameter    code:       读取状态
     */
    internal func broadcastCallback(_ address: Address, bytes: [UInt8], code: Int) {
        
        callback.callbackAll(any: (address, bytes, code))
    }
}

public extension Socket {
    
    // MARK: - Callback
    
    class Callback<T> {
        
        // MARK: - Parameter
        
        /// 回调字典
        var dictionary: [String: (T)->Void] = [:]
        
        /// 信号
        var semaphore = DispatchSemaphore(value: 1)
        
        // MARK: - Callback
        
        /**
         添加回调
         
         - parameter    key:            回调标识
         - parameter    callback:       回调
         */
        func add(_ key: String, callback: @escaping (T)->Void) {
            
            semaphore.wait()
            
            dictionary[key] = callback
            
            semaphore.signal()
        }
        
        /**
         删除回调
         
         - parameter    key:    回调标识
         */
        func remove(_ key: String) {
            
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
         是否有值
         
         - parameter    key:            回调标识
         */
        func isValue(_ key: String) -> Bool {
            
            var bool = false
            
            semaphore.wait()
            
            bool = dictionary[key] != nil
            
            semaphore.signal()
            
            return bool
        }
        
        /**
         回调结果
         
         - parameter    key:            回调标识
         - parameter    any:            回调结果
         - parameter    isRemove:       是否删除回调
         */
        func callback(key: String , any: T, isRemove: Bool = false) {
            
            semaphore.wait()
            
            if let callback = dictionary[key] {
                
                /// 防止卡住异步处理
                DispatchQueue.global().async {
                    
                    callback(any)
                }
                
                if isRemove {
                    
                    dictionary.removeValue(forKey: key)
                }
            }
            
            semaphore.signal()
        }
        
        /**
         回调所有结果
         
         - parameter    any:            回调结果
         - parameter    isRemove:       是否删除回调
         */
        func callbackAll(any: T, isRemove: Bool = false) {
            
            semaphore.wait()
            
            for (_, v) in dictionary {
                
                /// 防止卡住异步处理
                DispatchQueue.global().async {
                    
                    v(any)
                }
            }
            
            if isRemove {
                
                dictionary.removeAll()
            }
            
            semaphore.signal()
        }
    }
}

public extension Socket {
    
    // MARK: - Dictionary
    
    class Dictionary<K,V> where K: Hashable, V: Any {
        
        // MARK: - Parameter
        
        /// 回调字典
        private var dictionary: [K: V] = [:]
        
        /// 信号
        private var semaphore = DispatchSemaphore(value: 1)
        
        // MARK: - Callback
        
        /**
         添加
         
         - parameter    key:            键
         - parameter    value:          值
         */
        func add(_ key: K, value: V) {
            
            semaphore.wait()
            
            dictionary[key] = value
            
            semaphore.signal()
        }
        
        /**
         删除
         
         - parameter    key:            键
         */
        func remove(_ key: K) -> V? {
            
            var value: V? = nil
            
            semaphore.wait()
            
            value = dictionary.removeValue(forKey: key)
            
            semaphore.signal()
            
            return value
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
         是否有值
         
         - parameter    key:            键
         */
        func isValue(_ key: K) -> Bool {
            
            var bool = false
            
            semaphore.wait()
            
            bool = dictionary[key] != nil
            
            semaphore.signal()
            
            return bool
        }
        
        /**
         字典
         */
        func dict() -> [K:V] {
            
            var dict: [K:V]
            semaphore.wait()
            dict = dictionary
            semaphore.signal()
            
            return dict
        }
    }
}
