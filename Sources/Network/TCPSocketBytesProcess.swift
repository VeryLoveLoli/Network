//
//  TCPSocketBytesProcess.swift
//  
//
//  Created by 韦烽传 on 2021/1/18.
//

import Foundation

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
