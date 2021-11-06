//
//  UIBarItem.swift
//  
//
//  Created by 韦烽传 on 2021/11/1.
//

import Foundation
import UIKit

extension UIBarItem: ImageLoadProtocol {
    
    /// 类型区分 类型
    public typealias EnumType = Any
    
    /**
     回调标识
     
     - parameter    enumType:       类型区分
     */
    public func callbackKey(_ enumType: Any?) -> String {
        
        if let type = enumType {
            
            return String(format: "%p-\(type)", self)
        }
        
        return String(format: "%p", self)
    }
    
    /**
     更新图片
     
     - parameter    mainImage:      图片
     - parameter    enumType:       类型区分
     */
    public func updateImage(_ mainImage: Image?, enumType: Any?) {
        
        image = mainImage?.item?.withRenderingMode(.alwaysOriginal)
    }
}
