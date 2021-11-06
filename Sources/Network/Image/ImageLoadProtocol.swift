//
//  ImageLoadProtocol.swift
//  
//
//  Created by 韦烽传 on 2021/11/1.
//

import Foundation

/**
 图片加载协议
 */
public protocol ImageLoadProtocol: AnyObject {
    
    /// 关联类型（用于区分对象有多个属性赋值）
    associatedtype EnumType
    
    /**
     回调标识
     
     - parameter    enumType:       类型区分
     */
    func callbackKey(_ enumType: EnumType?) -> String
    
    /**
     清除回调
     
     - parameter    enumType:       类型区分
     */
    func cancelCallback(_ enumType: EnumType?)
    
    /**
     主线程更新图片
     
     - parameter    mainImage:      图片
     - parameter    enumType:       类型区分
     */
    func mainThreadImage(_ mainImage: Image?, enumType: EnumType?)
    
    /**
     更新图片
     
     - parameter    mainImage:      图片
     - parameter    enumType:       类型区分
     */
    func updateImage(_ mainImage: Image?, enumType: EnumType?)
    
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
              defaultImage: Image?,
              enumType: EnumType?,
              success: ((Image)->Void)?,
              progress: ((Int64, Int64)->Void)?,
              error: ((Error)->Void)?)
    
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
              defaultImage: Image?,
              enumType: EnumType?,
              success: ((Image)->Void)?,
              progress: ((Int64, Int64)->Void)?,
              error: ((Error)->Void)?)
    
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
              defaultImage: Image?,
              enumType: EnumType?,
              success: ((Image)->Void)?,
              progress: ((Int64, Int64)->Void)?,
              error: ((Error)->Void)?)
}

/**
 图片加载协议实现
 */
public extension ImageLoadProtocol {
    
    /**
     清除回调
     
     - parameter    enumType:       类型区分
     */
    func cancelCallback(_ enumType: EnumType? = nil) {
        
        /// 删除数据回调
        Image.network.sessionDelegate.dataCallback.remove(callbackKey: callbackKey(enumType))
        /// 删除路径回调
        Image.network.sessionDelegate.pathCallback.remove(callbackKey: callbackKey(enumType))
        /// 删除进度回调
        Image.network.sessionDelegate.progressCallback.remove(callbackKey: callbackKey(enumType))
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
        
        Image.load(request, callbackKey: callbackKey(enumType), success: { [weak self] image in
            
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
}
