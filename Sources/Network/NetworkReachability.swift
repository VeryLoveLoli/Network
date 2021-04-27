//
//  NetworkReachability.swift
//  
//
//  Created by 韦烽传 on 2021/1/18.
//

import Foundation
import SystemConfiguration

/**
 网络可达性
 */
open class NetworkReachability {
    
    /**
     网络状态
     */
    public enum Status {
        /// 未知
        case unowned
        /// 无法访问
        case notReachable
        /// Wi-Fi
        case wifi
        /// 蜂窝网络
        case cellular
        
        /**
         初始化
         */
        public init(_ flags: SCNetworkReachabilityFlags?) {
            
            guard let flags = flags else {
                
                self = .unowned
                
                return
            }
            
            guard flags.isActuallyReachable else {
                
                self = .notReachable
                
                return
            }
            
            self = flags.isCellular ? .cellular : .wifi
        }
    }
    
    /// 默认
    public static let `default` = NetworkReachability()
    
    /// 可达性
    private let reachability: SCNetworkReachability
    
    /// 队列
    public let queue = DispatchQueue(label: "NetworkReachability.serial")
    
    /// 侦听回调
    private var listeningCallback: ((Status) -> Void)?
    
    /// 可达性标记
    open var flags: SCNetworkReachabilityFlags? {
        
        var flags = SCNetworkReachabilityFlags()

        return SCNetworkReachabilityGetFlags(reachability, &flags) ? flags : nil
    }
    
    /// 网络状态
    open var status: Status {
        
        Status(flags)
    }
    
    /**
     初始化
     */
    private init(reachability: SCNetworkReachability) {
        
        self.reachability = reachability
    }
    
    /**
     0.0.0.0地址侦听网络可达性
     */
    public convenience init?() {
        
        var zero = sockaddr()
        zero.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zero.sa_family = sa_family_t(AF_INET)

        guard let reachability = SCNetworkReachabilityCreateWithAddress(nil, &zero) else { return nil }

        self.init(reachability: reachability)
    }
    
    /**
     主机名侦听可达性
     */
    public convenience init?(host: String) {
        
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, host) else { return nil }

        self.init(reachability: reachability)
    }
    
    /**
     侦听
     
     - parameter    callback:       回调
     */
    @discardableResult
    open func startListening(_ callback: @escaping (Status)->Void) -> Bool {
        
        stopListening()
        
        listeningCallback = callback
        
        /// 上下文
        var context = SCNetworkReachabilityContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        /// 回调
        let callBack: SCNetworkReachabilityCallBack = { _, flags, info in
            guard let info = info else { return }

            let instance = Unmanaged<NetworkReachability>.fromOpaque(info).takeUnretainedValue()
            instance.networkReachabilityCallBack(flags)
        }
        /// 设置队列
        guard SCNetworkReachabilitySetDispatchQueue(reachability, queue) else { return false }
        /// 设置回调
        guard SCNetworkReachabilitySetCallback(reachability, callBack, &context) else { return false }
        
        /// 使用创建的`flags`回调一次网络可达性
        if let flags = flags {
            
            networkReachabilityCallBack(flags)
        }
        
        return true
    }
    
    /**
      停止侦听
     */
    func stopListening() {
        
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
        
        listeningCallback = nil
    }
    
    /**
      网络可达回调
     */
    func networkReachabilityCallBack(_ flags: SCNetworkReachabilityFlags) {
        
        DispatchQueue.main.async { [weak self] in
            
            self?.listeningCallback?(Status(flags))
        }
    }
}

// MARK: - 网络可达性标记

extension SCNetworkReachabilityFlags {
    
    /// 是否可达
    var isReachable: Bool { contains(.reachable) }
    /// 是否需要链接
    var isConnectionRequired: Bool { contains(.connectionRequired) }
    /// 是否可自动链接
    var canConnectAutomatically: Bool { contains(.connectionOnDemand) || contains(.connectionOnTraffic) }
    /// 是否无需用户交互即可连接
    var canConnectWithoutUserInteraction: Bool { canConnectAutomatically && !contains(.interventionRequired) }
    /// 是否实际可达
    var isActuallyReachable: Bool { isReachable && (!isConnectionRequired || canConnectWithoutUserInteraction) }
    /// 是否蜂窝
    var isCellular: Bool {
        #if os(iOS) || os(tvOS)
        return contains(.isWWAN)
        #else
        return false
        #endif
    }

    /// 可达性描述
    var readableDescription: String {
        
        /**
         `transientConnection`                      瞬态连接
         `reachable`                                            可达的
         `connectionRequired`                        需要连接
         `connectionOnTraffic`                      交通连接
         `interventionRequired`                    需要干预
         `connectionOnDemand`                        按需连接
         `isLocalAddress`                                是本地地址
         `isDirect`                                             是直接的
         `isWWAN`                                                 是WWAN
         `connectionAutomatic`                     自动连接
         */
        
        let W = isCellular ? "W" : "-"
        let R = isReachable ? "R" : "-"
        let c = isConnectionRequired ? "c" : "-"
        let t = contains(.transientConnection) ? "t" : "-"
        let i = contains(.interventionRequired) ? "i" : "-"
        let C = contains(.connectionOnTraffic) ? "C" : "-"
        let D = contains(.connectionOnDemand) ? "D" : "-"
        let l = contains(.isLocalAddress) ? "l" : "-"
        let d = contains(.isDirect) ? "d" : "-"
        let a = contains(.connectionAutomatic) ? "a" : "-"

        return "\(W)\(R) \(c)\(t)\(i)\(C)\(D)\(l)\(d)\(a)"
    }
}
