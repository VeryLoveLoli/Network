//
//  Socket.swift
//  NetworkTest
//
//  Created by 韦烽传 on 2019/4/21.
//  Copyright © 2019 韦烽传. All rights reserved.
//

import Foundation

/**
 Socket连接类型
 */
public enum SocketConnectType {
    
    /// TCP
    case tcp
    /// UDP
    case udp
}

/**
 地址
 */
public struct Address: Hashable {
    
    /// IP
    public let ip: String
    /// 端口
    public let port: UInt16
    
    // MARK: - init
    
    public init(_ ip: String, port: UInt16) {
        
        self.ip = ip
        self.port = port
    }
    
    public init(addr: sockaddr) {
        
        self.init(data: addr.sa_data)
    }
    
    public init(data: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)) {
        
        var x0 = Int(data.0)
        var x1 = Int(data.1)
        
        x0 = (x0 < 0 ? x0 + 256 : x0) * 256
        x1 = x1 < 0 ? x1 + 256 : x1
        
        self.init("\(data.2.uint8()).\(data.3.uint8()).\(data.4.uint8()).\(data.5.uint8())", port: UInt16(x0 + x1))
    }
    
    public init(sockname socket_id: Int32) {
        
        var addr = sockaddr()
        var len = socklen_t.init(16)
        getsockname(socket_id, &addr, &len)
        
        self.init(addr: addr)
    }
    
    public init(peername socket_id: Int32) {
        
        var addr = sockaddr()
        var len = socklen_t.init(16)
        getpeername(socket_id, &addr, &len)
        
        self.init(addr: addr)
    }
    
    /**
     sockaddr
     */
    public func sockaddrStruct() -> sockaddr {
        
        var addr = sockaddr()
        memset(&addr, 0, MemoryLayout.stride(ofValue: addr))
        addr.sa_len = UInt8(MemoryLayout.stride(ofValue: addr))
        addr.sa_family = UInt8(AF_INET)
        addr.sa_data = data()
        
        return addr
    }
    
    /**
     data
     */
    private func data() -> (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8) {
        
        var x0 : Int = (Int(port) & 0b1111111100000000) >> 8
        var x1 : Int = (Int(port) & 0b0000000011111111)
        
        x0 = x0 > 127 ? x0 - 256 : x0
        x1 = x1 > 127 ? x1 - 256 : x1
        
        var array = [Int8].init(repeating: 0, count: 4)
        
        var i = 0
        
        for value in ip.components(separatedBy: ".") {
            
            if let uint8 = UInt8(value) {
                
                array[i] = uint8.int8()
            }
            
            i += 1
        }
        
        return (Int8(x0), Int8(x1),                                 /// 端口号
            array[0], array[1], array[2], array[3],                 /// IP地址
            0, 0, 0, 0, 0, 0, 0, 0)                                 /// 对齐
    }
    
    // MARK: - static
    
    /**
     主机名 -> IP
     
     - parameter    host:   主机名
     */
    public static func hostnameToIP(_ host: String) -> String? {
        
        var ip : String?
        
        let data = host.data(using: String.Encoding.utf8)
        
        if data != nil {
            
            var bytes = [Int8].init(repeating: 0x0, count: data!.count)
            (data! as NSData).getBytes(&bytes, length: bytes.count)
            
            let hostname = gethostbyname(&bytes)
            
            if hostname != nil {
                
                var h = hostent()
                memcpy(&h, hostname, MemoryLayout.stride(ofValue: h))
                
                if h.h_addr_list != nil {
                    
                    var addr = in_addr()
                    memcpy(&addr, h.h_addr_list[0], MemoryLayout.stride(ofValue: addr))
                    
                    ip = String(cString: inet_ntoa(addr))
                }
            }
        }
        
        return ip
    }
}

public extension UInt8 {
    
    /**
     Int8
     */
    func int8() -> Int8 {
        
        if self > 127 {
            
            return Int8(Int(self) - 256)
        }
        
        return Int8(self)
    }
}

public extension Int8 {
    
    /**
     UInt8
     */
    func uint8() -> UInt8 {
        
        if self < 0 {
            
            return UInt8(Int(self) + 256)
        }
        
        return UInt8(self)
    }
}

/// Socket 回调   (地址,字节,读取状态)
public typealias SocketCallback = (Address, [UInt8], Int)->Void

/**
 Socket
 */
open class Socket {
    
    /// 端口
    open private(set) var port: UInt16
    /// 连接类型
    public let type: SocketConnectType
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
    fileprivate static func `default`(_ port: UInt16, type: SocketConnectType) -> Self? {
        
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
    public required init(_ id: Int32, port: UInt16, type: SocketConnectType) {
        
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
    fileprivate func broadcastCallback(_ address: Address, bytes: [UInt8], code: Int) {
        
        serialQueue.async {
            
            for (_, callback) in self.callback {
                callback(address, bytes, code)
            }
        }
    }
}

/**
 UDP Socket
 */
open class UDP: Socket {
    
    // MARK: - init

    /**
     创建 UDP
     
     - parameter    port:       端口
     */
    public static func `default`(_ port: UInt16 = 0) -> Self? {
        
        return self.default(port, type: .udp)
    }
    
    // MARK: - socket

    /**
     等待字节
     */
    open func waitBytes() {
        
        recvSerialQueue.async {
            
            var code : Int
            
            repeat {
                
                var bytes : [UInt8] = [UInt8](repeating: 0x0, count: 1024)
                
                var addr = sockaddr()
                var len = socklen_t.init(16)
                
                code = recvfrom(self.id, &bytes, bytes.count, 0, &addr, &len)
                
                let address = Address.init(addr: addr)
                
                self.broadcastCallback(address, bytes: bytes, code: code)
                
            } while code > 0
        }
    }
    
    /**
     发送数据
     
     - parameter    address:        地址
     - parameter    data:           发送的数据
     - parameter    statusCode:     状态码 sendto()函数的返回值
     */
    open func sendtoData(_ address: Address, data: Data, statusCode: @escaping (Int)->Void) {
        
        sendtoBytes(address, bytes: [UInt8].init(data), statusCode: statusCode)
    }
    
    /**
     发送字节
     
     - parameter    address:        地址
     - parameter    bytes:          发送的字节
     - parameter    statusCode:     状态码 sendto()函数的返回值
     */
    open func sendtoBytes(_ address: Address, bytes: [UInt8], statusCode: @escaping (Int)->Void) {
        
        sendSerialQueue.async {
            
            var addr = address.sockaddrStruct()
            
            var sendBytes = bytes
            
            let sendCode = sendto(self.id, &sendBytes, sendBytes.count, 0, &addr, UInt32(MemoryLayout.stride(ofValue: addr)))
            
            statusCode(sendCode)
        }
    }
}

/**
 TCP Socket 字节处理协议
 */
public protocol TCPSocketBytesProcess {
    
    /// 字节
    var bytes: [UInt8] { set get }
    /// 读取状态
    var code: Int { set get }
    
    /**
     读取字节
     
     - parameter    bytes:      字节
     - parameter    code:       读取状态
     */
    func recv(_ bytes: [UInt8], code: Int) -> Bool
}

/**
 TCP Socket
 */
open class TCP: Socket {
    
    /// 字节处理
    open var bytesProcess: TCPSocketBytesProcess?

    /**
     创建 TCP
     
     - parameter    port:       端口
     */
    public static func `default`(_ port: UInt16 = 0) -> Self? {

        return self.default(port, type: .tcp)
    }
}

/**
 TCP Client
 */
open class TCPClient: TCP {
    
    /**
     初始化 TCP
     
     - parameter    id:         socket
     - parameter    port:       端口
     */
    fileprivate convenience init(_ id: Int32, port: UInt16 = 0) {
        
        self.init(id, port: port, type: .tcp)
    }
    
    // MARK: - socket
    
    /**
     连接服务器
     
     - parameter    address:        地址
     - parameter    statusCode:     状态码 connect()函数的返回值
     */
    open func connection(_ address: Address, statusCode: @escaping (Int32)->Void) {
        
        sendSerialQueue.async {
            
            ///设置服务器地址
            var addr = address.sockaddrStruct()
            /// 链接服务器
            let status = connect(self.id, &addr, UInt32(MemoryLayout.stride(ofValue: addr)))
            
            if status == 0 {
                
            }
            
            statusCode(status)
        }
    }
    
    /**
     等待字节
     */
    open func waitBytes() {
        
        recvSerialQueue.async {
            
            var code : Int
            
            repeat {
                
                var bytes : [UInt8] = [UInt8](repeating: 0x0, count: 1024)
                
                code = recv(self.id, &bytes, bytes.count, 0)
                
                /// 连接端已关闭
                if code == 0 {
                    
                    self.cancel()
                }
                
                /// 字节处理
                if self.bytesProcess?.recv(bytes, code: code) ?? true {
                    
                    if let b = self.bytesProcess?.bytes, let c = self.bytesProcess?.code {
                        
                        bytes = b
                        code = c
                        self.bytesProcess?.bytes = []
                    }
                    
                    let address = Address.init(peername: self.id)
                    
                    self.broadcastCallback(address, bytes: bytes, code: code)
                }
                
            } while code > 0
        }
    }
    
    /**
     发送数据
     
     - parameter    data:           发送的数据
     - parameter    repeatCount:    失败重发次数
     - parameter    statusCode:     状态码 send()函数的返回值
     */
    open func sendData(_ data: Data, repeatCount: Int = 0, statusCode: @escaping (Int)->Void) {
        
        sendBytes([UInt8].init(data), repeatCount: repeatCount, statusCode: statusCode)
    }
    
    /**
     发送字节
     
     - parameter    bytes:          发送的字节
     - parameter    repeatCount:    失败重发次数
     - parameter    statusCode:     状态码 send()函数的返回值
     */
    open func sendBytes(_ bytes: [UInt8], repeatCount: Int = 0, statusCode: @escaping (Int)->Void) {
        
        sendSerialQueue.async {
            
            var index = 0
            
            var repeat_index = 0
            
            var status = 0
            
            repeat {
                
                let len = min(bytes.count - index, 1024)
                
                var sendBytes = [UInt8](bytes[index..<(index+len)])
                
                let sendCode = send(self.id, &sendBytes, len, 0)
                
                if sendCode == len {
                    
                    status += sendCode
                    index += len
                    repeat_index = 0
                }
                else if repeat_index < repeatCount {
                    
                    repeat_index += 1
                }
                else {
                    
                    status = sendCode
                    break
                }
                
            } while index < bytes.count
            
            statusCode(status)
        }
    }
}

/**
 TCP Server
 */
open class TCPServer: TCP {
    
    /// 客户字典
    private var clientDict: [Address: TCPClient] = [:]
    /// 客户字典（使用 serialQueue 队列 获取 避免多线程同时操作）
    open var clients: [Address: TCPClient] {
        
        let dispatchSemaphore = DispatchSemaphore.init(value: 0)
        
        var dict: [Address: TCPClient] = [:]
        
        serialQueue.async {
            
            dict = self.clientDict
            dispatchSemaphore.signal()
        }
        
        dispatchSemaphore.wait()
        
        return dict
    }
    
    // MARK: - Client
    
    /**
     添加客户
     
     - parameter    address:    地址
     - parameter    client:     客户
     */
    fileprivate func addClient(_ address: Address, client: TCPClient) {
        
        serialQueue.async {
            
            self.clientDict[address] = client
        }
    }
    
    /**
     删除客户
     
     - parameter    address:    地址
     */
    open func removeClient(_ address: Address) {
        
        serialQueue.async {
            
            let client = self.clientDict.removeValue(forKey: address)
            client?.cancel()
        }
    }
    
    /**
     删除所有客户
     */
    open func removeAllClient() {
        
        serialQueue.async {
            
            for (address, client) in self.clientDict {
                self.clientDict.removeValue(forKey: address)
                client.cancel()
            }
        }
    }
    
    // MARK: - socket

    /**
     监听客户端连接
     */
    open func listenClientConnect() {
        
        recvSerialQueue.async {
            
            if listen(self.id, Int32.max) == 0 {
                
                while self.status >= 0 {
                    
                    var addr = sockaddr()
                    var len = socklen_t.init(16)
                    
                    let id = accept(self.id, &addr, &len)
                    
                    if id != -1 {
                        
                        let address = Address.init(addr: addr)
                        
                        let client = TCPClient.init(id)
                        client.bytesProcess = self.bytesProcess
                        
                        client.addCallback(address.ip + ":\(address.port)", callback: { [weak self] (address, bytes, code) in
                            
                            if bytes.count == 0 && code == 0 {
                                
                                self?.removeClient(address)
                            }
                            
                            self?.broadcastCallback(address, bytes: bytes, code: code)
                        })
                        
                        client.waitBytes()
                        
                        self.addClient(address, client: client)
                        
                        /// 广播新的客户
                        self.broadcastCallback(address, bytes: [], code: Int(id))
                    }
                }
            }
        }
    }
    
    /**
     发送数据（所有客户）
     
     - parameter    data:           发送的数据
     - parameter    repeatCount:    失败重发次数
     - parameter    clientStatus:   Address 客户地址; Int 状态码 send()函数的返回值
     */
    open func send(_ data: Data, repeatCount: Int = 0, clientStatus: @escaping (Address, Int)->Void) {
        
        send([UInt8].init(data), repeatCount: repeatCount, clientStatus: clientStatus)
    }
    
    /**
     发送字节（所有客户）
     
     - parameter    bytes:          发送的字节
     - parameter    repeatCount:    失败重发次数
     - parameter    clientStatus:   Address 客户地址; Int 状态码 send()函数的返回值
     */
    open func send(_ bytes: [UInt8], repeatCount: Int = 0, clientStatus: @escaping (Address, Int)->Void) {
        
        serialQueue.async {
            
            for (address, client) in self.clientDict {
                
                client.sendBytes(bytes, repeatCount: repeatCount) { (code) in
                    
                    clientStatus(address, code)
                }
            }
        }
    }
}
