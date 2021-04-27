//
//  File.swift
//  
//
//  Created by 韦烽传 on 2021/2/2.
//

import Foundation

/**
 网络操作协议
 */
public protocol NetworkOperationDelegate {
    
    /**
     进度
     */
    func operation(_ key: String, received: Int64, expectedToReceive: Int64)
    
    /**
     错误
     */
    func operation(_ key: String, error: Error)
    
    /**
     完成
     */
    func operation(_ key: String, data: Data)
    
    /**
     完成
     */
    func operation(_ key: String, path: String)
}
