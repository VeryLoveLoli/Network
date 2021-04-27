//
//  TCPClient.swift
//  
//
//  Created by 韦烽传 on 2021/1/18.
//

import Foundation

/**
 TCP Client
 */
open class TCPClient: TCP {
    
    /**
     初始化 TCP
     
     - parameter    id:         socket
     - parameter    port:       端口
     */
    internal convenience init(_ id: Int32, port: UInt16 = 0) {
        
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
