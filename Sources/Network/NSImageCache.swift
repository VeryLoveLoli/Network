//
//  File.swift
//  
//
//  Created by 韦烽传 on 2021/2/2.
//

import Foundation

#if os(macOS)

import AppKit

/**
 图片缓存
 */
open class NSImageCache: NSCache<NSString, NSImage> {
    
    public static let `default` = NSImageCache.init()
    
    override public init() {
        
        super.init()
        
        // TODO: 不知道macOS的内存警告怎么写
    }
}

#endif
