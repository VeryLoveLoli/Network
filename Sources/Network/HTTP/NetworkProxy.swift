//
//  NetworkProxy.swift
//  
//
//  Created by 韦烽传 on 2021/2/20.
//

import Foundation
import CFNetwork

/**
 网络代理
 */
open class NetworkProxy {
    
    /**
     代理信息
     
     - parameter    url:    检测地址
     */
    public static func info(_ url: URL) -> Dictionary<CFString, Any>? {
        
        /**
         对象 -> 指针
         */
        func bridge<T: AnyObject>(_ obj: T) -> UnsafeMutableRawPointer {
            
            return Unmanaged.passUnretained(obj).toOpaque()
        }
        
        /**
         指针 -> 对象
         */
        func bridge<T: AnyObject>(raw: UnsafeRawPointer) -> T {
            
            return Unmanaged<T>.fromOpaque(raw).takeUnretainedValue()
        }
        
        if let proxySettingsRaw = CFNetworkCopySystemProxySettings()?.toOpaque() {
            
            let proxySettings: CFDictionary = bridge(raw: proxySettingsRaw)
            
            let proxiesRaw = CFNetworkCopyProxiesForURL(url as CFURL, proxySettings)
            
            let proxies: NSArray = bridge(raw: proxiesRaw.toOpaque())
            
            if let settings = proxies[0] as? Dictionary<CFString, Any> {
                
                return settings
            }
        }
        
        return nil
    }
    
    /**
     是否使用代理
     
     - parameter    url:    检测地址
     */
    public static func isUse(_ url: URL = URL(string: "https://www.baidu.com")!) -> Bool {
        
        if let settings = info(url) {
            
            if let host = settings[kCFProxyTypeKey] as? String, host != kCFProxyTypeNone as String {
                
                return true
            }
        }
        
        return false
    }
}
