//
//  Image.swift
//  
//
//  Created by 韦烽传 on 2021/11/1.
//

import Foundation
import UIKit

/**
 图片
 */
open class Image {
    
    // MARK: - Parameter
    
    /// 默认GIF缓存大小（10MB）
    public static var gifSize = 1024*1024*10
    
    /// 格式
    public var format: Image.Format = Image.Format.unknown
    /// 列表
    public var items: [UIImage] = []
    /// 时间
    public var duration: TimeInterval = 0
    /// 数据
    public var data: Data?
    /// 图片
    public var item: UIImage? { return items.first }
    
    /// GIF 图片源
    public var gifImageSource: CGImageSource?
    /// GIF 列表
    public var gifItems: [GIFItem]?
    
    // MARK: - init
    
    /**
     初始化
     
     - parameter    data:           图片数据
     - parameter    gifCacheSize:   GIF缓存大小
     `nil`则存储`GIF`图片数组`items`和总时长`duration`。设置大小则存储`CGImageSource`，按照大小存储图片组`gifItems`
     存储规则：
     size<=0：全部存储
     占用内存大小<size：全部存储
     占用内存大小<2*size：并且图片数量>=2：隔张存储
     占用内存大小<n*size：并且图片数量>=n：隔n-1张存储
     其余情况不存储
     */
    public init?(_ data: Data, gifCacheSize: Int? = nil) {
        
        format = Image.format(data)
        
        switch format {
            
        case .gif, .tiff:
            
            if let cacheSize = gifCacheSize {
                
                if let animationGIF = Image.animationGIF(data, cacheSize: cacheSize) {
                    
                    items = []
                    duration = 0
                    
                    gifImageSource = animationGIF.0
                    gifItems = animationGIF.1
                }
                else {
                    
                    return nil
                }
            }
            else {
                
                if let animation = Image.animation(data) {
                    
                    items = animation.0
                    duration = animation.1
                }
                else {
                    
                    return nil
                }
            }
                        
        default:
            
            if let image = UIImage(data: data) {
                
                items = [image]
                duration = 0
            }
            else {
                
                return nil
            }
        }
        
        self.data = data
    }
    
    /**
     初始化
     */
    public init(_ items: UIImage..., format: Image.Format = .unknown, duration: TimeInterval = 0) {
        
        self.items = items
        self.format = format
        self.duration = duration
    }
    
    /**
     初始化
     */
    public init(_ items: [UIImage] = [], format: Image.Format = .unknown, duration: TimeInterval = 0) {
        
        self.items = items
        self.format = format
        self.duration = duration
    }
}

/**
 图片初始化
 */
public extension Image {
    
    // MARK: - convenience init
    
    /**
     初始化
     */
    convenience init(_ names: String..., format: Image.Format = .unknown, duration: TimeInterval = 0) {
        
        self.init(names, format: format, duration: duration)
    }
    
    /**
     初始化
     */
    convenience init(_ names: [String], format: Image.Format = .unknown, duration: TimeInterval = 0) {
        
        var items: [UIImage] = []
        
        for item in names {
            
            if let image = UIImage(named: item) {
                
                items.append(image)
            }
        }
        
        self.init(items, format: format, duration: duration)
    }
}

/**
 图片格式
 */
public extension Image {
    
    // MARK: - Format
    
    /**
     格式
     */
    enum Format {
        case png
        case jpg
        case jpeg
        case gif
        case tiff
        case bmp
        case ico
        case cur
        case xbm
        case unknown
    }
    
    /**
     图片格式
     
     - parameter    data:   图片数据
     
     - returns  图片格式
     */
    static func format(_ data: Data) -> Image.Format {
        
        if data.count > 8 {
            
            var bytes = [UInt8](data[0..<2])
            
            switch bytes {
            case [0xff, 0xd8]:
                return .jpg
            case [0xff, 0xd9]:
                return .jpeg
            case [0x49, 0x49]:
                return .tiff
            case [0x4d, 0x4d]:
                return .tiff
            case [0x42, 0x4d]:
                return .bmp
            default:
                bytes = [UInt8](data[0..<6])
                switch bytes {
                case [0x47, 0x49, 0x46, 0x38, 0x39, 0x61]:
                    return .gif
                case [0x47, 0x49, 0x46, 0x38, 0x37, 0x61]:
                    return .gif
                default:
                    bytes = [UInt8](data[0..<8])
                    switch bytes {
                    case [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]:
                        return .png
                    case [0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x20, 0x20]:
                        return .ico
                    case [0x00, 0x00, 0x02, 0x00, 0x01, 0x00, 0x20, 0x20]:
                        return .cur
                    case [0x23, 0x64, 0x65, 0x66, 0x69, 0x6e, 0x65, 0x20]:
                        return .xbm
                    default:
                        return .unknown
                    }
                }
            }
        }
        
        return .unknown
    }
}

/**
 图片GIF项
 */
public extension Image {
    
    // MARK: - GIFItem
    
    /**
     GIF项
     */
    class GIFItem {
        
        /// 时间
        public var duration: TimeInterval
        /// 索引
        public var index: Int
        /// 图片
        public var image: CGImage?
        
        /**
         初始化
         */
        init(duration: TimeInterval, index: Int, image: CGImage? = nil) {
            
            self.duration = duration
            self.index = index
            self.image = image
        }
    }
}

/**
 图片动画
 */
public extension Image {
    
    // MARK: - Animation
    
    /**
     动画图片
     
     - parameter    data:   图片数据
     
     - returns  动画图片数组，动画时间
     */
    static func animation(_ data: Data) -> ([UIImage], TimeInterval)? {
        
        /// 获取图片资源
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        
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
        
        if images.count == 0 {
            
            return nil
        }
        
        return (images, duration)
    }
    
    /**
     动画图片GIF
     
     - parameter    data:           图片数据
     - parameter    cacheSize:      缓存大小
     存储规则：
     size<=0：全部存储
     占用内存大小<size：全部存储
     占用内存大小<2*size：并且图片数量>=2：隔张存储
     占用内存大小<n*size：并且图片数量>=n：隔n-1张存储
     其余情况不存储
     
     - returns  动画GIF图片源，动画GIF列表
     */
    static func animationGIF(_ data: Data, cacheSize: Int) -> (CGImageSource, [Image.GIFItem])? {
        
        /// 获取图片资源
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        
        /// 获取图片数量
        let count = CGImageSourceGetCount(source)
        
        var items: [Image.GIFItem] = []
        var duration: TimeInterval = 0
        
        /// 总大小
        var totalSize = 0
        /// 存储比率
        var ratio = 0
        
        for i in 0..<count {
            
            /// 获取图片
            guard let cgimage = CGImageSourceCreateImageAtIndex(source, i, nil) else {
                
                continue
            }
            
            if totalSize == 0 {
                
                /// 计算总大小
                totalSize = cgimage.height * cgimage.width * count * 4
                
                if totalSize < cacheSize || cacheSize <= 0 {
                    
                    /// 存储全部
                    ratio = 1
                }
                else {
                    
                    let multiple = totalSize/cacheSize + 1
                    
                    if count >= multiple {
                        
                        /// 隔`multiple-1`张存储
                        ratio = multiple
                    }
                    else {
                        
                        /// 不存储
                        ratio = 0
                    }
                }
            }
            
            /// 是否缓存
            var isCache = false
            
            if ratio > 0 {
                
                if i%ratio == 0 {
                    
                    isCache = true
                }
            }
            
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
            
            let item = GIFItem(duration: duration, index: i, image: isCache ? cgimage : nil)
            
            items.append(item)
        }
        
        if items.count == 0 {
            
            return nil
        }
        
        return (source, items)
    }
}

/**
 图片加载
 */
public extension Image {
    
    // MARK: - Load
    
    /**
     加载网络图片
     
     - parameter    request:            请求
     - parameter    callbackKey:        回调标识
     - parameter    cacheOptions:       缓存选项
     - parameter    gifCacheSize:       GIF缓存大小
     - parameter    success:            成功：图片或GIF图
     - parameter    progress:           加载进度
     - parameter    error:              失败：错误
     */
    static func load(_ request: URLRequest,
                     callbackKey: String = "\(Date.init().timeIntervalSince1970)-\(arc4random())",
                     cacheOptions: Set<Image.CacheOption> = [.ram, .disk],
                     gifCacheSize: Int? = nil,
                     success: ((Image)->Void)? = nil,
                     progress: ((Int64, Int64)->Void)? = nil,
                     error: ((Error)->Void)? = nil) {
        
        /// 请求标识
        guard let key = Network.key(request) else { error?(Network.MessageError("Request Not key")); return }
        
        /// 获取缓存
        if cacheOptions.contains(.ram), let cache = Image.Cache.default.object(forKey: key as NSString) {
            
            success?(cache)
            progress?(1,1)
        }
        else {
            
            Image.network.load(request, key: key, callbackKey: callbackKey, cachePolicy: cacheOptions.contains(.disk) ? .cache : .reload, data: { data in
                
                if let image = Image(data, gifCacheSize: gifCacheSize) {
                    
                    if cacheOptions.contains(.ram) {
                        
                        Image.Cache.default.setObject(image, forKey: key as NSString)
                    }
                    
                    success?(image)
                }
                else {
                    
                    error?(Network.MessageError("Data Not Image"))
                }
                
            }, path: { path in
                
            }, progress: progress, error: error)
        }
    }
}

/**
 图片网络
 */
public extension Image {
    
    // MARK: - Network
    
    /// 图片网络
    static var network = Network(configuration: URLSessionConfiguration.default, queue: nil, path: NSHomeDirectory() + "/Documents/Network/Image/")
}

/**
 图片缓存
 */
public extension Image {
    
    // MARK: - Cache
    
    /**
     图片缓存
     */
    class Cache: NSCache<NSString, Image> {
        
        /// 默认
        public static let `default` = Image.Cache.init()
        
        /**
         初始化
         */
        override public init() {
            
            super.init()
            
            /// 注册内存警告
            NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { [weak self] (notification) in
                
                /// 删除缓存
                self?.removeAllObjects()
            }
        }
    }
}

/**
 图片缓存选项
 */
public extension Image {
    
    /**
     缓存选项
     */
    enum CacheOption {
        
        /// 内存（内存有图片则回调；内存无图片则加载，加载完成缓存图片。无该选项，不会在内存中查询图片，加载完成也不会在内存中存储图片）
        case ram
        /// 磁盘（磁盘有图片则回调；磁盘无图片则加载。无该选项，不会在磁盘中查询图片。无论是否有该选项加载完成都磁盘存储图片）
        case disk
    }
}
