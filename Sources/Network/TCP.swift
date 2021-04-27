//
//  TCP.swift
//  
//
//  Created by 韦烽传 on 2021/1/18.
//

import Foundation

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
