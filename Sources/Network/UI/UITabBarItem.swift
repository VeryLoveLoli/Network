//
//  UITabBarItem.swift
//  
//
//  Created by 韦烽传 on 2021/11/1.
//

import Foundation
import UIKit

extension UITabBarItem {
    
    /// 类型区分 类型 是否是选择图片
    public typealias EnumType = Bool
    
    /**
     回调标识

     - parameter    enumType:       类型区分
     */
    public func callbackKey(_ enumType: Bool?) -> String {
        
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
    public func updateImage(_ mainImage: Image?, enumType: Bool?) {
        
        let type = enumType ?? false
        
        if type {
            
            image = mainImage?.item?.withRenderingMode(.alwaysOriginal)
        }
        else {
            
            selectedImage = mainImage?.item?.withRenderingMode(.alwaysOriginal)
        }
    }
}
