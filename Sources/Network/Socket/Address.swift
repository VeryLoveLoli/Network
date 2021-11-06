//
//  Address.swift
//  
//
//  Created by 韦烽传 on 2021/1/18.
//

import Foundation

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
