//
//  TCPServer.swift
//  
//
//  Created by 韦烽传 on 2021/1/18.
//

import Foundation

/**
 TCP Server
 */
open class TCPServer: TCP {
    
    /// 客户字典
    private var clientDict = Socket.Dictionary<Address, TCPClient>()
    /// 客户字典
    open var clients: [Address: TCPClient] {
        
        return clientDict.dict()
    }
    
    // MARK: - Client
    
    /**
     添加客户
     
     - parameter    address:    地址
     - parameter    client:     客户
     */
    fileprivate func addClient(_ address: Address, client: TCPClient) {
        
        clientDict.add(address, value: client)
    }
    
    /**
     删除客户
     
     - parameter    address:    地址
     */
    open func removeClient(_ address: Address) {
        
        clientDict.remove(address)?.cancel()
    }
    
    /**
     删除所有客户
     */
    open func removeAllClient() {
        
        for (_, client) in clients {
            
            client.cancel()
        }
        
        clientDict.removeAll()
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
        
        for (address, client) in clients {
            
            client.sendBytes(bytes, repeatCount: repeatCount) { (code) in
                
                clientStatus(address, code)
            }
        }
    }
}
