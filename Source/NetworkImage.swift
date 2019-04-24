//
//  NetworkImage.swift
//  NetworkTest
//
//  Created by 韦烽传 on 2019/4/20.
//  Copyright © 2019 韦烽传. All rights reserved.
//

import Foundation

public extension Network {
    
    /// 图片网络
    static let image = Network.init("NetworkImage", max: 3, directory: NSHomeDirectory() + "/Documents/Network/Image/")
}

#if os(iOS) || os(watchOS) || os(tvOS)

import UIKit

/**
 图片缓存
 */
public class UIImageCache: NSCache<NSString, UIImage> {
    
    public static let `default` = UIImageCache.init()
    
    override init() {
        
        super.init()
        
        /// 注册内存警告
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: OperationQueue.main) { (notification) in
            
            /// 删除缓存
            self.removeAllObjects()
        }
    }
}

public extension DataCache {
    
    static let GIFDataCache = DataCache.init("GIFDataCache")
}

/**
 图片加载
 */
public extension UIImageView {
    
    /**
     加载
     
     - parameter    urlString:      地址字符串
     - parameter    defaultImage:   默认图片
     - parameter    isCache:        是否缓存
     - parameter    isDisk:         是否磁盘存储
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
     - parameter    isCache:        是否缓存
     - parameter    isDisk:         是否磁盘存储
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
                if let gifCache = DataCache.GIFDataCache.get(url.absoluteString) {
                    
                    _ = self.gif(gifCache)
                    
                    progress(1,1)

                    return
                }
                else if let cache = UIImageCache.default.object(forKey: url.absoluteString as NSString) {
                    
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
            
            Network.image.removeCallback(id)
            
            Network.image.load(url, isCache: false, isDisk: isDisk, isStart: true, callbackID: id, progress: progress) { [weak self] (error, data, path) in

                var urlData = data
                
                if let diskPath = path {

                    do {
                        
                        urlData = try Data.init(contentsOf: URL.init(fileURLWithPath: diskPath))
                        
                    } catch {
                        
                    }
                }

                if let imageData = urlData {

                    if let count = self?.gif(imageData), count > 0 {
                        
                        if isCache {
                            
                            DataCache.GIFDataCache.add(url.absoluteString, data: imageData)
                        }
                    }
                    else if let image = UIImage.init(data: imageData) {
                        
                        if isCache {
                            
                            UIImageCache.default.setObject(image, forKey: url.absoluteString as NSString)
                        }
                        
                        DispatchQueue.main.async {
                            
                            self?.image = image
                        }
                    }
                }
            }
        }
    }
    
    /**
     GIF
     
     - parameter    data:   GIF数据
     */
    public func gif(_ data: Data) -> Int {
        
        /// 获取图片资源
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            
            return 0
        }
        
        /// 获取图片数量
        let count = CGImageSourceGetCount(source)
        
        var images: [UIImage] = []
        var duration: TimeInterval = 0
        
        for i in 0..<count {
            
            /// 获取图片
            guard let cgimage = CGImageSourceCreateImageAtIndex(source, i, nil) else {
                
                continue
            }
            
            let image = UIImage.init(cgImage: cgimage)
            
            images.append(image)
            
            /// 获取时间
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) else {
                
                continue
            }
            
            guard let gifDict = (properties as Dictionary)[kCGImagePropertyGIFDictionary] else {
                
                continue
            }
            
            guard let time = (gifDict as? Dictionary<CFString, Any>)?[kCGImagePropertyGIFDelayTime] else {
                
                continue
            }
            
            duration += (time as? TimeInterval) ?? 0
        }
        
        DispatchQueue.main.async {
            
            if images.count > 0 {
                
                self.image = images[0]
            }
            
            self.animationImages = images
            self.animationDuration = duration
            self.startAnimating()
        }
        
        return images.count
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
     - parameter    isCache:        是否缓存
     - parameter    isDisk:         是否磁盘存储
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
     - parameter    isCache:        是否缓存
     - parameter    isDisk:         是否磁盘存储
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
            
            Network.image.removeCallback(id)
            
            Network.image.load(url, isCache: false, isDisk: isDisk, isStart: true, callbackID: id, progress: progress) { [weak self] (error, data, path) in
                
                var urlData = data
                
                if let diskPath = path {
                    
                    do {
                        
                        urlData = try Data.init(contentsOf: URL.init(fileURLWithPath: diskPath))
                        
                    } catch {
                        
                    }
                }
                
                if let imageData = urlData, let image = UIImage.init(data: imageData) {
                    
                    if isCache {
                        
                        UIImageCache.default.setObject(image, forKey: url.absoluteString as NSString)
                    }
                    
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
public class NSImageCache: NSCache<NSString, NSImage> {
    
    public static let `default` = NSImageCache.init()
    
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
     - parameter    isCache:        是否缓存
     - parameter    isDisk:         是否磁盘存储
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
     - parameter    isCache:        是否缓存
     - parameter    isDisk:         是否磁盘存储
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
            
            Network.image.removeCallback(id)
            
            Network.image.load(url, isCache: false, isDisk: isDisk, isStart: true, callbackID: id, progress: progress) { [weak self] (error, data, path) in
                
                var urlData = data
                
                if let diskPath = path {
                    
                    do {
                        
                        urlData = try Data.init(contentsOf: URL.init(fileURLWithPath: diskPath))
                        
                    } catch {
                        
                    }
                }
                
                if let imageData = urlData, let image = NSImage.init(data: imageData) {
                    
                    if isCache {
                        
                        NSImageCache.default.setObject(image, forKey: url.absoluteString as NSString)
                    }
                    
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
     - parameter    isCache:        是否缓存
     - parameter    isDisk:         是否磁盘存储
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
     - parameter    isCache:        是否缓存
     - parameter    isDisk:         是否磁盘存储
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
            
            Network.image.removeCallback(id)
            
            Network.image.load(url, isCache: false, isDisk: isDisk, isStart: true, callbackID: id, progress: progress) { [weak self] (error, data, path) in
                
                var urlData = data
                
                if let diskPath = path {
                    
                    do {
                        
                        urlData = try Data.init(contentsOf: URL.init(fileURLWithPath: diskPath))
                        
                    } catch {
                        
                    }
                }
                
                if let imageData = urlData, let image = NSImage.init(data: imageData) {
                    
                    if isCache {
                        
                        NSImageCache.default.setObject(image, forKey: url.absoluteString as NSString)
                    }
                    
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
