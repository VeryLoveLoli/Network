//
//  Socket.swift
//  NetworkTest
//
//  Created by 韦烽传 on 2019/4/21.
//  Copyright © 2019 韦烽传. All rights reserved.
//

import Foundation

/// Socket 回调   (地址,字节,读取状态)
public typealias SocketCallback = (Address, [UInt8], Int)->Void

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
    /// 串行队列（处理回调字典、回调闭包）
    internal let serialQueue: DispatchQueue
    /// 发送串行队列
    internal let sendSerialQueue: DispatchQueue
    /// 读取串行队列
    internal let recvSerialQueue: DispatchQueue
    /// 回调字典
    internal var callback: [String: SocketCallback] = [:]
    
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
        serialQueue = DispatchQueue.init(label: "\(key).\(type).scoket.serial")
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
        
        serialQueue.async {
            
            self.callback[key] = callback
        }
    }
    
    /**
     删除回调
     
     - parameter    key:        标识
     */
    open func removeCallback(_ key: String) {
        
        serialQueue.async {
            
            self.callback.removeValue(forKey: key)
        }
    }
    
    /**
     删除所有回调
     
     */
    open func removeAllCallback() {
        
        serialQueue.async {
            
            self.callback.removeAll()
        }
    }
    
    /**
     广播回调
     
     - parameter    address:    地址
     - parameter    bytes:      数据
     - parameter    code:       读取状态
     */
    internal func broadcastCallback(_ address: Address, bytes: [UInt8], code: Int) {
        
        serialQueue.async {
            
            for (_, callback) in self.callback {
                callback(address, bytes, code)
            }
        }
    }
}
