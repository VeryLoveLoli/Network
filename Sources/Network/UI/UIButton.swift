//
//  UIButton.swift
//  
//
//  Created by 韦烽传 on 2021/11/1.
//

import Foundation
import UIKit

extension UIButton: ImageLoadProtocol {
    
    /// 类型区分（点击状态，是否是图标）`true:图标`、`false:背景`
    public typealias EnumType = (UIControl.State, Bool)
    
    /**
     回调标识
     
     - parameter    enumType:       类型区分
     */
    public func callbackKey(_ enumType: (UIControl.State, Bool)?) -> String {
        
        let type = enumType ?? (.normal, true)
        
        return String(format: "%p-\(type)", self)
    }
    
    /**
     更新图片
     
     - parameter    mainImage:      图片
     - parameter    enumType:       类型区分
     */
    public func updateImage(_ mainImage: Image?, enumType: (UIControl.State, Bool)?) {
        
        let type = enumType ?? (.normal, true)
        
        if type.1 {
            
            setImage(mainImage?.item, for: type.0)
        }
        else {
            
            setBackgroundImage(mainImage?.item, for: type.0)
        }
    }
}
