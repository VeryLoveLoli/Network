//
//  GIFImageView.swift
//  
//
//  Created by 韦烽传 on 2021/12/19.
//

import Foundation
import UIKit

/**
 GIF图片视图
 */
open class GIFImageView: UIImageView, CADisplayLinkProtocol {
    
    // MARK: - 属性
    
    /// 图片源
    open internal(set) var imageSource: CGImageSource?
    /// 图片列表
    open internal(set) var items: [Image.GIFItem]?
    
    /// 当前时间
    open internal(set) var currentDuration: TimeInterval = 0
    /// 当前索引
    open internal(set) var currentIndex = 0
    /// 当前图片
    open internal(set) var currentImage: CGImage?
    /// 当前重复次数
    open internal(set) var currentRepeatCount = 0
    
    /// 屏幕刷新
    open internal(set) var displayLink: CADisplayLink?
    
    /// 是否动画
    open override var isAnimating: Bool {
        
        if imageSource != nil {
            
            return (displayLink != nil) ? true : false
        }
        else {
            
            return super.isAnimating
        }
    }
    
    // MARK: - 更新GIF
    
    /**
     更新GIF数据
     
     - parameter    data:           图片数据
     - parameter    cacheSize:      缓存大小
     */
    open func updateGIF(_ data: Data, cacheSize: Int? = Image.gifSize) {
        
        let image = Image(data, gifCacheSize: cacheSize)
        
        mainThreadImage(image)
    }
    
    /**
     更新GIF数据
     
     - parameter    source:     图片源
     - parameter    list:       图片列表
     */
    open func updateGIF(_ source: CGImageSource?, list: [Image.GIFItem]?) {
        
        let bool = isAnimating
        
        if bool {
            
            stopAnimating()
        }
        
        imageSource = source
        items = list
        
        if bool {
            
            startAnimating()
        }
    }
    
    // MARK: - 动画
    
    /**
     开始动画
     */
    open override func startAnimating() {
        
        if imageSource != nil {
            
            if displayLink == nil {
                
                currentIndex = 0
                currentDuration = 0
                currentImage = image?.cgImage
                
                /* 弱引用无效，`displayLink`会一直持有`self`
                weak var weakSelf = self
                
                if let strongSelf = weakSelf {
                    
                    displayLink = CADisplayLink(target: strongSelf, selector: #selector(displayLinkEvent(_:)))
                }
                */
                
                let target = CADisplayLinkTarget()
                target.delegate = self
                
                displayLink = CADisplayLink(target: target, selector: #selector(target.displayLinkHandle(_:)))
                displayLink?.add(to: RunLoop.main, forMode: ProcessInfo.processInfo.activeProcessorCount > 1 ? .common : .default)
            }
            
            displayLink?.isPaused = false
        }
        else {
            
            super.startAnimating()
        }
    }
    
    /**
     停止动画
     */
    open override func stopAnimating() {
        
        if imageSource != nil {
            
            if displayLink != nil {
                
                displayLink?.invalidate()
                displayLink = nil
            }
            
            currentImage = image?.cgImage
            layer.setNeedsDisplay()
        }
        else {
            
            super.stopAnimating()
        }
    }
    
    /**
     暂停动画
     */
    open func pauseAnimating() {
        
        displayLink?.isPaused = true
    }
    
    // MARK: - CADisplayLinkProtocol
    
    open func displayLinkHandle(_ link: CADisplayLink) {
        
        guard let source = imageSource else { return }
        guard let list = items else { return }
        
        currentDuration += link.duration
        
        /// 图片索引
        var index = -1
        
        for i in currentIndex..<list.count {
                        
            if list[i].duration > currentDuration {
                
                index = i
                break
            }
        }
        
        if index == -1 {
            
            currentIndex = 0
            currentDuration = link.duration
            
            if currentRepeatCount == Int.max {
                
                currentRepeatCount = 0
            }
            
            currentRepeatCount += 1
        }
        else if currentIndex != index {
            
            currentIndex = index
        }
        else {
            
            return
        }
        
        if animationRepeatCount > 0 && animationRepeatCount == currentRepeatCount {
            
            stopAnimating()
            
            return
        }
        
        if let image = list[currentIndex].image {
            
            currentImage = image
        }
        else {
            
            currentImage = CGImageSourceCreateImageAtIndex(source, list[currentIndex].index, nil)
        }
        
        layer.setNeedsDisplay()
    }
    
    // MARK: - 图层显示
    
    /**
     显示
     */
    open override func display(_ layer: CALayer) {
        
        layer.contents = currentImage
    }
    
    // MARK: - 事件
    
    /**
     获取图片
     
     - parameter    index:      索引
     */
    open func image(_ index: Int) -> UIImage? {
        
        guard let source = imageSource else { return nil }
        guard let list = items else { return nil }
        guard list.count > index else { return nil }
        
        if let cgimage = list[index].image {
            
            return UIImage(cgImage: cgimage)
        }
        else {
            
            guard let cgimage = CGImageSourceCreateImageAtIndex(source, list[index].index, nil) else { return nil }
            
            return UIImage(cgImage: cgimage)
        }
    }
    
    // MARK: - deinit
    
    deinit {
        
        stopAnimating()
    }
}

/**
 GIF图片视图加载协议
 */
public extension GIFImageView {
    
    // MARK: - ImageLoadProtocol
    
    /**
     加载网络图片
     
     - parameter    urlString:      地址字符串
     - parameter    defaultImage:   默认图
     - parameter    enumType:       类型区分
     - parameter    success:        成功：图片
     - parameter    progress:       加载进度
     - parameter    error:          失败：错误
     */
    func load(_ urlString: String,
              defaultImage: Image? = nil,
              enumType: EnumType? = nil,
              success: ((Image)->Void)? = nil,
              progress: ((Int64, Int64)->Void)? = nil,
              error: ((Error)->Void)? = nil) {
        
        if let url = URL(string: urlString) {
            
            load(url, defaultImage: defaultImage, enumType: enumType, success: success, progress: progress, error: error)
        }
        else {
            
            cancelCallback(enumType)
            mainThreadImage(defaultImage, enumType: enumType)
            
            error?(Network.MessageError("\(urlString) Not URL"))
        }
    }
    
    /**
     加载网络图片
     
     - parameter    url:            地址
     - parameter    defaultImage:   默认图
     - parameter    enumType:       类型区分
     - parameter    success:        成功：图片
     - parameter    progress:       加载进度
     - parameter    error:          失败：错误
     */
    func load(_ url: URL,
              defaultImage: Image? = nil,
              enumType: EnumType? = nil,
              success: ((Image)->Void)? = nil,
              progress: ((Int64, Int64)->Void)? = nil,
              error: ((Error)->Void)? = nil) {
        
        load(URLRequest(url: url), defaultImage: defaultImage, enumType: enumType, success: success, progress: progress, error: error)
    }
    
    /**
     加载网络图片
     
     - parameter    request:        请求
     - parameter    defaultImage:   默认图
     - parameter    enumType:       类型区分
     - parameter    success:        成功：图片或GIF图
     - parameter    progress:       加载进度
     - parameter    error:          失败：错误
     */
    func load(_ request: URLRequest,
              defaultImage: Image? = nil,
              enumType: EnumType? = nil,
              success: ((Image)->Void)? = nil,
              progress: ((Int64, Int64)->Void)? = nil,
              error: ((Error)->Void)? = nil) {
        
        cancelCallback(enumType)
        
        /// 是否已返回值（缓存有值会立即返回）
        var bool = false
        
        Image.load(request, callbackKey: callbackKey(enumType), cacheOptions: [.ram, .disk], gifCacheSize: Image.gifSize, success: { [weak self] image in
            
            bool = true
            self?.mainThreadImage(image, enumType: enumType)
            success?(image)
            
        }, progress: progress) { errorMessage in
            
            bool = true
            error?(errorMessage)
        }
        
        if bool {
           
            return
        }
        
        mainThreadImage(defaultImage, enumType: enumType)
    }
    
    /**
     主线程更新图片
     
     - parameter    mainImage:      图片
     - parameter    enumType:       类型区分
     */
    func mainThreadImage(_ mainImage: Image? = nil, enumType: EnumType? = nil) {
        
        if Thread.isMainThread {
            
            updateImage(mainImage, enumType: enumType)
        }
        else {
            
            DispatchQueue.main.async {
                
                self.updateImage(mainImage, enumType: enumType)
            }
        }
    }
    
    /**
     更新图片
     
     - parameter    mainImage:      图片
     - parameter    enumType:       类型区分
     */
    func updateImage(_ mainImage: Image? = nil, enumType: EnumType? = nil) {
        
        if isAnimating {
            
            stopAnimating()
        }
        
        if  mainImage?.gifImageSource != nil {
            
            updateGIF(mainImage?.gifImageSource, list: mainImage?.gifItems)
            image = image(0)
        }
        else {
            
            image = mainImage?.item
            animationImages = mainImage?.items
            animationDuration = mainImage?.duration ?? 0
        }
        
        startAnimating()
    }
}

/**
 屏幕刷新协议
 */
public protocol CADisplayLinkProtocol: NSObjectProtocol {
    
    /**
     屏幕刷新处理
     
     - parameter    link:       屏幕刷新
     */
    func displayLinkHandle(_ link: CADisplayLink)
}

/**
 屏幕刷新目标
 */
open class CADisplayLinkTarget {
    
    /// 协议
    open weak var delegate: CADisplayLinkProtocol?
    
    /**
     屏幕刷新处理
     
     - parameter    link:       屏幕刷新
     */
    @objc open func displayLinkHandle(_ link: CADisplayLink) {
        
        delegate?.displayLinkHandle(link)
    }
}
