//
//  NetworAnimationImageLoadProtocol.swift
//  
//
//  Created by 韦烽传 on 2021/11/1.
//

import Foundation
import UIKit

/**
 图片加载动画协议
 */
public protocol ImageLoadAnimationProtocol: ImageLoadPropertyProtocol {
    
    /// 动画图片
    var animationImages: [UIImage]? { get set }
    /// 动画时间
    var animationDuration: TimeInterval { get set }
    /// 是否在动画
    var isAnimating: Bool { get }
    
    /// 开始动画
    func startAnimating()
    /// 停止动画
    func stopAnimating()
}

/**
 图片加载动画协议实现
 */
public extension ImageLoadAnimationProtocol {
    
    /**
     更新图片
     
     - parameter    mainImage:      图片
     - parameter    enumType:       类型区分
     */
    func updateImage(_ mainImage: Image? = nil, enumType: EnumType? = nil) {
        
        if isAnimating {
            
            stopAnimating()
        }
        
        image = mainImage?.item
        animationImages = mainImage?.items
        animationDuration = mainImage?.duration ?? 0
        
        startAnimating()
    }
}
