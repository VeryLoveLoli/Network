//
//  NetworkImage.swift
//  NetworkTest
//
//  Created by 韦烽传 on 2019/4/20.
//  Copyright © 2019 韦烽传. All rights reserved.
//

import Foundation

#if os(iOS) || os(watchOS) || os(tvOS)

import UIKit

/**
 图片缓存
 */
class UIImageCache: NSCache<NSString, UIImage> {
    
    static let `default` = UIImageCache.init()
    
    override init() {
        
        super.init()
        
        /// 注册内存警告
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: OperationQueue.main) { (notification) in
            
            /// 删除缓存
            self.removeAllObjects()
        }
    }
}

/**
 图片加载
 */
public extension UIImageView {
    
    /**
     加载
     
     - parameter    urlString:      地址字符串
     - parameter    defaultImage:   默认图片
     - parameter    isDisk:         是否磁盘存储
     - parameter    isStart:        是否立即开始
     - parameter    progress:       进度  (当前字节,总字节)
     */
    func load(_ urlString: String,
              defaultImage: UIImage? = nil,
              isCache: Bool = true,
              isDisk: Bool = true,
              progress: @escaping NetworkCallbackProgress = { _,_ in }) {
        
        if let url = URL.init(string: urlString) {
            
            load(url, defaultImage: defaultImage, isCache: isCache, isDisk: isDisk, progress: progress)
        }
    }
    
    /**
     加载
     
     - parameter    url:            地址
     - parameter    defaultImage:   默认图片
     - parameter    isDisk:         是否磁盘存储
     - parameter    isStart:        是否立即开始
     - parameter    progress:       进度  (当前字节,总字节)
     */
    func load(_ url: URL,
              defaultImage: UIImage? = nil,
              isCache: Bool = true,
              isDisk: Bool = true,
              progress: @escaping NetworkCallbackProgress = { _,_ in }) {

        DispatchQueue.global().async {
            
            if isCache {
                
                /// 获取缓存
                if let cache = UIImageCache.default.object(forKey: url.absoluteString as NSString) {
                    
                    DispatchQueue.main.async {
                        
                        self.image = cache
                    }
                    
                    progress(1,1)
                    
                    return
                }
            }
            
            DispatchQueue.main.async {
                
                self.image = defaultImage
            }
            
            let id = String.init(format: "%p", self)
            
            Network.default.removeCallback(id)
            
            Network.default.load(url, isDisk: true, isStart: true, callbackID: id, progress: progress) { [weak self] (error, data, path) in

                if let diskPath = path, let image = UIImage.init(contentsOfFile: diskPath) {

                    UIImageCache.default.setObject(image, forKey: url.absoluteString as NSString)
                    
                    DispatchQueue.main.async {

                        self?.image = image
                    }
                }

                if let imageData = data, let image = UIImage.init(data: imageData) {

                    UIImageCache.default.setObject(image, forKey: url.absoluteString as NSString)

                    DispatchQueue.main.async {

                        self?.image = image
                    }
                }
            }
        }
    }
}

/**
 图片加载
 */
public extension UIButton {
    
    /**
     加载
     
     - parameter    urlString:      地址字符串
     - parameter    isBackground:   是否是背景图片
     - parameter    state:          状态
     - parameter    defaultImage:   默认图片
     - parameter    isDisk:         是否磁盘存储
     - parameter    isStart:        是否立即开始
     - parameter    progress:       进度  (当前字节,总字节)
     */
    func load(_ urlString: String,
              isBackground: Bool = false,
              state: UIControl.State = .normal,
              defaultImage: UIImage? = nil,
              isCache: Bool = true,
              isDisk: Bool = true,
              progress: @escaping NetworkCallbackProgress = { _,_ in }) {
        
        if let url = URL.init(string: urlString) {
            
            load(url, isBackground: isBackground, state: state, defaultImage: defaultImage, isCache: isCache, isDisk: isDisk, progress: progress)
        }
    }
    
    /**
     加载
     
     - parameter    url:            地址
     - parameter    isBackground:   是否是背景图片
     - parameter    state:          状态
     - parameter    defaultImage:   默认图片
     - parameter    isDisk:         是否磁盘存储
     - parameter    isStart:        是否立即开始
     - parameter    progress:       进度  (当前字节,总字节)
     */
    func load(_ url: URL,
              isBackground: Bool = false,
              state: UIControl.State = .normal,
              defaultImage: UIImage? = nil,
              isCache: Bool = true,
              isDisk: Bool = true,
              progress: @escaping NetworkCallbackProgress = { _,_ in }) {
        
        DispatchQueue.global().async {
            
            if isCache {
                
                /// 获取缓存
                if let cache = UIImageCache.default.object(forKey: url.absoluteString as NSString) {
                    
                    DispatchQueue.main.async {
                        
                        if isBackground {
                            
                            self.setBackgroundImage(cache, for: state)
                        }
                        else {
                            
                            self.setImage(cache, for: state)
                        }
                    }
                    
                    progress(1,1)
                    
                    return
                }
            }
            
            DispatchQueue.main.async {
                
                if isBackground {
                    
                    self.setBackgroundImage(defaultImage, for: state)
                }
                else {
                    
                    self.setImage(defaultImage, for: state)
                }
            }
            
            let id = String.init(format: "%p-\(isBackground ? "background" : "")-\(state.rawValue)", self)
            
            Network.default.removeCallback(id)
            
            Network.default.load(url, isDisk: true, isStart: true, callbackID: id, progress: progress) { [weak self] (error, data, path) in
                
                if let diskPath = path, let image = UIImage.init(contentsOfFile: diskPath) {
                    
                    UIImageCache.default.setObject(image, forKey: url.absoluteString as NSString)
                    
                    DispatchQueue.main.async {
                        
                        if isBackground {
                            
                            self?.setBackgroundImage(image, for: state)
                        }
                        else {
                            
                            self?.setImage(image, for: state)
                        }
                    }
                }
                
                if let imageData = data, let image = UIImage.init(data: imageData) {
                    
                    UIImageCache.default.setObject(image, forKey: url.absoluteString as NSString)
                    
                    DispatchQueue.main.async {
                        
                        if isBackground {
                            
                            self?.setBackgroundImage(image, for: state)
                        }
                        else {
                            
                            self?.setImage(image, for: state)
                        }
                    }
                }
            }
        }
    }
}

#elseif os(macOS)

import AppKit

/**
 图片缓存
 */
class NSImageCache: NSCache<NSString, NSImage> {
    
    static let `default` = NSImageCache.init()
    
    override init() {
        
        super.init()
        
        // TODO: 不知道macOS的内存警告怎么写
    }
}

public extension NSImageView {
    
    /**
     加载
     
     - parameter    urlString:      地址字符串
     - parameter    defaultImage:   默认图片
     - parameter    isDisk:         是否磁盘存储
     - parameter    isStart:        是否立即开始
     - parameter    progress:       进度  (当前字节,总字节)
     */
    func load(_ urlString: String,
              defaultImage: NSImage? = nil,
              isCache: Bool = true,
              isDisk: Bool = true,
              progress: @escaping NetworkCallbackProgress = { _,_ in }) {
        
        if let url = URL.init(string: urlString) {
            
            load(url, defaultImage: defaultImage, isCache: isCache, isDisk: isDisk, progress: progress)
        }
    }
    
    /**
     加载
     
     - parameter    url:            地址
     - parameter    defaultImage:   默认图片
     - parameter    isDisk:         是否磁盘存储
     - parameter    isStart:        是否立即开始
     - parameter    progress:       进度  (当前字节,总字节)
     */
    func load(_ url: URL,
              defaultImage: NSImage? = nil,
              isCache: Bool = true,
              isDisk: Bool = true,
              progress: @escaping NetworkCallbackProgress = { _,_ in }) {
        
        DispatchQueue.global().async {
            
            if isCache {
                
                /// 获取缓存
                if let cache = NSImageCache.default.object(forKey: url.absoluteString as NSString) {
                    
                    DispatchQueue.main.async {
                        
                        self.image = cache
                    }
                    
                    progress(1,1)
                    
                    return
                }
            }
            
            DispatchQueue.main.async {
                
                self.image = defaultImage
            }
            
            let id = String.init(format: "%p", self)
            
            Network.default.removeCallback(id)
            
            Network.default.load(url, isDisk: true, isStart: true, callbackID: id, progress: progress) { [weak self] (error, data, path) in
                
                if let diskPath = path, let image = NSImage.init(contentsOfFile: diskPath) {
                    
                    NSImageCache.default.setObject(image, forKey: url.absoluteString as NSString)
                    
                    DispatchQueue.main.async {
                        
                        self?.image = image
                    }
                }
                
                if let imageData = data, let image = NSImage.init(data: imageData) {
                    
                    NSImageCache.default.setObject(image, forKey: url.absoluteString as NSString)
                    
                    DispatchQueue.main.async {
                        
                        self?.image = image
                    }
                }
            }
        }
    }
}

/**
 图片加载
 */
public extension NSButton {
    
    /**
     加载
     
     - parameter    urlString:      地址字符串
     - parameter    isAlternate:    是否是替代图片
     - parameter    state:          状态
     - parameter    defaultImage:   默认图片
     - parameter    isDisk:         是否磁盘存储
     - parameter    isStart:        是否立即开始
     - parameter    progress:       进度  (当前字节,总字节)
     */
    func load(_ urlString: String,
              isAlternate: Bool = false,
              defaultImage: NSImage? = nil,
              isCache: Bool = true,
              isDisk: Bool = true,
              progress: @escaping NetworkCallbackProgress = { _,_ in }) {
        
        if let url = URL.init(string: urlString) {
            
            load(url, isAlternate: isAlternate, defaultImage: defaultImage, isCache: isCache, isDisk: isDisk, progress: progress)
        }
    }
    
    /**
     加载
     
     - parameter    url:            地址
     - parameter    isAlternate:    是否是替代图片
     - parameter    defaultImage:   默认图片
     - parameter    isDisk:         是否磁盘存储
     - parameter    isStart:        是否立即开始
     - parameter    progress:       进度  (当前字节,总字节)
     */
    func load(_ url: URL,
              isAlternate: Bool = false,
              defaultImage: NSImage? = nil,
              isCache: Bool = true,
              isDisk: Bool = true,
              progress: @escaping NetworkCallbackProgress = { _,_ in }) {
        
        DispatchQueue.global().async {
            
            if isCache {
                
                /// 获取缓存
                if let cache = NSImageCache.default.object(forKey: url.absoluteString as NSString) {
                    
                    DispatchQueue.main.async {
                        
                        if isAlternate {
                            
                            self.alternateImage = cache
                        }
                        else {
                            
                            self.image = cache
                        }
                    }
                    
                    progress(1,1)
                    
                    return
                }
            }
            
            DispatchQueue.main.async {
                
                if isAlternate {
                    
                    self.alternateImage = defaultImage
                }
                else {
                    
                    self.image = defaultImage
                }
            }
            
            let id = String.init(format: "%p-\(isAlternate ? "isAlternate" : "")", self)
            
            Network.default.removeCallback(id)
            
            Network.default.load(url, isDisk: true, isStart: true, callbackID: id, progress: progress) { [weak self] (error, data, path) in
                
                if let diskPath = path, let image = NSImage.init(contentsOfFile: diskPath) {
                    
                    NSImageCache.default.setObject(image, forKey: url.absoluteString as NSString)
                    
                    DispatchQueue.main.async {
                        
                        if isAlternate {
                            
                            self?.alternateImage = image
                        }
                        else {
                            
                            self?.image = image
                        }
                    }
                }
                
                if let imageData = data, let image = NSImage.init(data: imageData) {
                    
                    NSImageCache.default.setObject(image, forKey: url.absoluteString as NSString)
                    
                    DispatchQueue.main.async {
                        
                        if isAlternate {
                            
                            self?.alternateImage = image
                        }
                        else {
                            
                            self?.image = image
                        }
                    }
                }
            }
        }
    }
}

#endif
