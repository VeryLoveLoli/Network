//
//  ImageLoadPropertyProtocol.swift
//  
//
//  Created by 韦烽传 on 2021/11/1.
//

import Foundation
import UIKit

/**
 图片加载属性协议
 */
public protocol ImageLoadPropertyProtocol: ImageLoadProtocol {
    
    /// 图片
    var image: UIImage? { get set }
}

/**
 图片加载属性协议实现
 */
public extension ImageLoadPropertyProtocol {
    
    /**
     更新图片
     
     - parameter    mainImage:      图片
     - parameter    enumType:       类型区分
     */
    func updateImage(_ mainImage: Image? = nil, enumType: EnumType? = nil) {
        
        image = mainImage?.item
    }
}
