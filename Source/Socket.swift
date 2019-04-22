//
//  Socket.swift
//  NetworkTest
//
//  Created by 韦烽传 on 2019/4/21.
//  Copyright © 2019 韦烽传. All rights reserved.
//

import Foundation

/**
 Socket 队列
 */
public struct SocketQueue {
    
    /// 串行队列
    public static let serial = DispatchQueue.init(label: "scoket.serial")
    /// 并行队列
    public static let concurrent = DispatchQueue.init(label: "scoket.concurrent", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    /// 任务组
    public static let group = DispatchGroup()
}

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
public struct Address {
    
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

/**
 Socket
 */
public class Socket {
    
    /// 端口
    public private(set) var port: UInt16
    /// 连接类型
    public let type: SocketConnectType
    /// Socket句柄
    public private(set) var id: Int32
    /// 连接状态
    public var status: Int32 { return fcntl(id, F_GETFL, 0)}
    /// 是否已开始
    private var isStart = false
    /// 读取数据处理
    public var recvProcess: (Address, [UInt8], Int)->Void = {_,_,_ in}
    /// 发送数据锁
    internal var sendLock = NSLock.init()
    
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
    internal required init(_ id: Int32, port: UInt16, type: SocketConnectType) {
        
        self.port = port
        self.type = type
        self.id = id
    }
    
    /**
     启动
     */
    public func start() {
        
        if isStart {
            
            return
        }
        
        isStart = true
        
        _ = bindAddress()
    }
    
    /**
     取消
     */
    public func cancel() {
        
        close(id)
    }
    
    // MARK: - socket
    
    /**
     绑定
     */
    private func bindAddress() -> Int32 {
        
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
    public func socketBuf(_ rcvbuf: UInt32 = 1024*1024, sndbuf: UInt32 = 1024*1024) {
        
        /// 读取缓冲
        var RCVBUF = rcvbuf
        setsockopt(id, SOL_SOCKET, SO_RCVBUF, &RCVBUF, UInt32(MemoryLayout.stride(ofValue: RCVBUF)))
        /// 发送缓冲
        var SNDBUF = sndbuf
        setsockopt(id, SOL_SOCKET, SO_SNDBUF, &SNDBUF, UInt32(MemoryLayout.stride(ofValue: SNDBUF)))
    }
}

/**
 UDP Socket
 */
public class UDP: Socket {
    
    /**
     创建 UDP
     
     - parameter    port:       端口
     */
    public static func `default`(_ port: UInt16 = 0) -> Self? {
        
        return self.default(port, type: .udp)
    }
    
    /**
     初始化 UDP
     
     - parameter    id:         socket
     - parameter    port:       端口
     */
    public convenience init(_ id: Int32, port: UInt16 = 0) {
        
        self.init(id, port: port, type: .udp)
    }
    
    /**
     读取数据
     
     - parameter    address:    地址
     - parameter    queue:      block队列
     - parameter    block:      读取到的结果; bytes:读取到的数据;    code:recvfrom()函数的返回值
     */
    open func recvfromData(_ queue: DispatchQueue, block: @escaping (_ address: Address, _ data: Data?, _ code: Int)->Void) -> Void {
        
        recvfromBytes(queue) { (address, bytes, code) in
            
            block(address, code < 0 ? nil : Data.init(bytes: bytes, count: code), code)
        }
    }
    
    /**
     读取数据
     
     - parameter    address:    地址
     - parameter    queue:      block队列
     - parameter    block:      读取到的结果; bytes:读取到的数据;    code:recvfrom()函数的返回值
     */
    open func recvfromBytes(_ queue: DispatchQueue, block: @escaping (_ address: Address, _ bytes: [UInt8], _ code: Int)->Void) -> Void {
        
        SocketQueue.concurrent.async {
            
            var code : Int
            
            repeat {
                
                var bytes : [UInt8] = [UInt8](repeating: 0x0, count: 1024)
                
                var addr = sockaddr()
                var len = socklen_t.init(16)
                
                code = recvfrom(self.id, &bytes, bytes.count, 0, &addr, &len)
                
                let address = Address.init(addr: addr)
                
                queue.async {
                    
                    block(address, bytes, code)
                }
                
            } while code > 0
        }
    }
    
    /**
     发送数据
     
     - parameter    address:    地址
     - parameter    data:       发送的数据
     - parameter    queue:      block队列
     - parameter    block:      发送结果; status:发送状态true=成功,false=失败;  code:sendto()函数的返回值
     */
    open func sendtoData(_ address: Address, data: Data, queue: DispatchQueue, block: @escaping (_ status: Bool, _ code: Int)->Void) -> Void {
        
        sendtoBytes(address, bytes: [UInt8].init(data), queue: queue, block: block)
    }
    
    /**
     发送数据
     
     - parameter    address:    地址
     - parameter    data:       发送的数据
     - parameter    queue:      block队列
     - parameter    block:      发送结果; status:发送状态true=成功,false=失败;  code:sendto()函数的返回值
     */
    open func sendtoBytes(_ address: Address, bytes: [UInt8], queue: DispatchQueue, block: @escaping (_ status: Bool, _ code: Int)->Void) -> Void {
        
        SocketQueue.concurrent.async {
            
            self.sendLock.lock()
            
            var addr = address.sockaddrStruct()
            
            var sendBytes = bytes
            
            let sendCode = sendto(self.id, &sendBytes, sendBytes.count, 0, &addr, UInt32(MemoryLayout.stride(ofValue: addr)))
            
            let status = sendCode > 0
            
            self.sendLock.unlock()
            
            queue.async(execute: {
                
                block(status, sendCode)
            })
        }
    }
}

/**
 TCP Socket
 */
public class TCP: Socket {
    
    /**
     创建 TCP
     
     - parameter    port:       端口
     */
    public static func `default`(_ port: UInt16 = 0) -> Self? {

        return self.default(port, type: .tcp)
    }
    
    /**
     初始化 TCP
     
     - parameter    id:         socket
     - parameter    port:       端口
     */
    public convenience init(_ id: Int32, port: UInt16 = 0) {

        self.init(id, port: port, type: .tcp)
    }
}

/**
 TCP Client
 */
public class TCPClient: TCP {
    
    /**
     连接服务器
     
     - parameter    address:    地址
     - parameter    block: 连接结果; status:连接状态 true=成功,false=失败; code:connection()函数的返回值
     */
    open func connection(_ address: Address, block: @escaping (_ status:Bool, _ code:Int32)->Void) -> Void {
        
        SocketQueue.concurrent.async {
            
            ///设置服务器地址
            var addr = address.sockaddrStruct()
            /// 链接服务器
            let status = connect(self.id, &addr, UInt32(MemoryLayout.stride(ofValue: addr)))
            
            if status == 0 {
                
            }
            
            block(status == 0, status)
        }
    }
    
    /**
     读取数据
     
     - parameter    queue:      block的队列
     - parameter    block:      读取到的结果; data:读取到的数据;    code:recv()函数的返回值
     */
    public func recvData(_ queue: DispatchQueue, block: @escaping (_ data: Data?, _ code: Int)->Void) -> Void {
        
        recvBytes(queue) { (bytes, code) in
            
            block(code > 0 ? Data.init(bytes: UnsafePointer<UInt8>(bytes), count: code) : nil, code)
        }
    }
    
    /**
     读取数据
     
     - parameter    queue:      block的队列
     - parameter    block:      读取到的结果; data:读取到的数据;    code:recv()函数的返回值
     */
    public func recvBytes(_ queue: DispatchQueue, block: @escaping (_ bytes: [UInt8], _ code: Int)->Void) -> Void {
        
        SocketQueue.concurrent.async {
            
            var code : Int
            
            repeat {
                
                var bytes : [UInt8] = [UInt8](repeating: 0x0, count: 1024)
                
                code = recv(self.id, &bytes, bytes.count, 0)
                
                /// 连接端已关闭
                if code == 0 {
                    
                    self.cancel()
                }
                
                queue.async {
                    
                    block(bytes, code)
                }
                
            } while code > 0
        }
    }
    
    /**
     发送数据
     
     - parameter    data:           发送的数据
     - parameter    repeatCount:    失败重发次数
     - parameter    block:          发送结果; status:发送状态true=成功,false=失败;  code:send()函数的返回值
     */
    public func sendData(_ data: Data, repeatCount: Int = 0, block: @escaping (_ status: Bool, _ code: Int)->Void) {
        
        sendBytes([UInt8].init(data), repeatCount: repeatCount, block: block)
    }
    
    /**
     发送数据
     
     - parameter    bytes:          发送的数据
     - parameter    repeatCount:    失败重发次数
     - parameter    block:          发送结果; status:发送状态true=成功,false=失败;  code:send()函数的返回值
     */
    public func sendBytes(_ bytes: [UInt8], repeatCount: Int = 0, block: @escaping (_ status: Bool, _ code: Int)->Void) {
        
        SocketQueue.concurrent.async {
            
            self.sendLock.lock()
            
            var index = 0
            
            var repeat_index = 0
            
            var status = true
            
            var sendCode : Int
            
            repeat {
                
                let len = min(bytes.count - index, 1024)
                
                var sendBytes = [UInt8](bytes[index..<(index+len)])
                
                sendCode = send(self.id, &sendBytes, len, 0)
                
                if sendCode == len {
                    
                    index += len
                    repeat_index = 0
                }
                else if repeat_index < repeatCount {
                    
                    repeat_index += 1
                }
                else {
                    
                    status = false
                    break
                }
                
            } while index < bytes.count
            
            self.sendLock.unlock()
            
            block(status, sendCode)
        }
    }
}

/**
 TCP Server
 */
public class TCPServer: TCP {
    
    /// 客户列表
    public var clientList: [TCPClient] = []
    /// 锁
    public let lock = NSLock.init()
    
    /**
     监听客户端连接
     */
    public func listenClientConnect() {
        
        SocketQueue.concurrent.async {
            
            if listen(self.id, Int32.max) == 0 {
                
                while self.status >= 0 {
                    
                    var addr = sockaddr()
                    var len = socklen_t.init(16)
                    
                    let id = accept(self.id, &addr, &len)
                    
                    if id != -1 {
                        
                        let client = TCPClient.init(id)
                        
                        SocketQueue.concurrent.async {
                            
                            self.lock.lock()
                            self.clientList.append(client)
                            self.lock.unlock()
                        }
                    }
                }
            }
        }
    }
}
