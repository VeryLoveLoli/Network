//
//  UDP.swift
//  
//
//  Created by 韦烽传 on 2021/1/18.
//

import Foundation

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
