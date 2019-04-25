# Network
一个简易的`Swift`语言`Network`

包含`HTTP``Socket``Image`

### 支持

##### `HTTP` `Image`
* `Cache`缓存
* `Disk`磁盘存储
* 队列顺序请求，可设置并发数量，完成一个自动请求下一个
* 可将请求立即请求，正在请求队列数量超过并发数量，会将最早的请求转移到等待队列前端
* 或者加入等待队列末尾(用于预加载再好不过了，特别是预加载图片列表)，如果正在请求队列数量低于并发数量，会自动将等待队列前端请求转移到正在请求队列
* 多方同一个请求，只请求一次，多方返回。
* `Image`扩展`UIImageView`、`UIButton`、`NSImageView`、`NSButton`、`GIF`

##### `Socket`
* 多方同一个请求，只请求一次，多方返回。
* `TCP`返回数据预处理

## 使用

### `Network``HTTP`

如果闭包包含`self`,加上`[weak self]`

```swift
Network.default.load("http://i0.hdslb.com/bfs/archive/24e031e495699e234526586deb80c65d337cbe4d.png") { [weak self] (error, data, path) in
    
    self.data = data
    print(error)
    print(data?.count)
    print(path)
}
```

项目中使用最好先扩展 `Network`，实现项目特有的`URLRequest`请求、`Data`数据解析

例如:

```swift
extension Network {
    
    /// xx请求
    static func xxRequest() -> URLRequest {
        
        /// 加密
        /// 设置HTTPHead
        /// 请求方式 GET/POST
    }
    
    /// xx解析
    static func xxAnalysis(_ data: Data?) -> Any {
        
        /// 解密
        /// 返回 XML/JSON/other
    }
    
    /// xxAPI
    static func xxAPI(progress: @escaping NetworkCallbackProgress = { _,_ in },
                      result: @escaping (Any)->Void) -> Any {
        
        Network.default.load(Network.xxRequest(), isCache: false, isDisk: false, isStart: true, callbackID: "\(Date.init().timeIntervalSince1970)\(arc4random())", progress: progress) { (error, data, path) in
            
            result(Network.xxAnalysis(data))
        }
    }
}
```

### `Image`

如果闭包包含`self`,加上`[weak self]`

设置UIImageView，其它也一样的

```swift
self.imageView.load("https://i0.hdslb.com/bfs/archive/5e889fec08dab8cd8f7c6cc0478265ecb9839493.gif", defaultImage: nil, isCache: true, isDisk: true) { (current, total) in
    
    print("image - \(current)/\(total) - \(String.init(format: "%.2f", Float(current)/Float(total)*100))%")
}
```

图片预加载 (必须磁盘存储，`UIImageView`、`NSImageView`等使用的缓存和`Network`不一样)

```swift
Network.image.load("http://i0.hdslb.com/bfs/archive/24e031e495699e234526586deb80c65d337cbe4d.png", isCache: false, isDisk: true, isStart: false) { (_, _, _) in }
```

### `Socket`

如果闭包包含`self`,加上`[weak self]`

##### `UDP`

```swift
/// 自动端口
let udp = UDP.default()
/// 指定端口
let udp = UDP.default(8888)
/// 绑定
if udp?.bindAddress() != 0 {
    
    print("绑定失败")
}

/* 绑定成功后 */

/// 等待数据
udp?.waitBytes()

/// 回调KEY
let key = "\(Date.init().timeIntervalSince1970)-\(arc4random())"

/// 添加回调
udp?.addCallback(key, callback: { (address, bytes, statusCode) in
    
    print("收到 \(address.ip):\(address.port) 数据")
    print(statusCode)
    print(bytes)
})

/// 发送信息
let bytes: [UInt8] = [1,2,3,4,5,6]
udp?.sendtoBytes(Address.init("127.0.0.1", port: 8889), bytes: bytes, statusCode: { (statusCode) in
    
    if statusCode == bytes.count {
        
        print("发送完成")
    }
})

/// 删除回调
udp?.removeCallback(key)
/// 删除所有回调
udp?.removeAllCallback()
/// 关闭Socket
udp?.cancel()
```

##### `TCPClient`

```swift
/// 自动端口
let tcpClient = TCPClient.default()
/// 指定端口
let tcpClient = TCPClient.default(8888)
/// 绑定
if tcpClient?.bindAddress() != 0 {
    
    print("绑定失败")
}

/* 绑定成功后 */

/// 连接服务器
tcpClient?.connection(Address.init("127.0.0.1", port: 8889), statusCode: { (statusCode) in
    
    if statusCode == 0 {
        
        print("连接成功")
    }
})

/* 连接成功后 */

/// 等待数据（连接成功后调用）
tcpClient?.waitBytes()

/// 回调KEY
let key = "\(Date.init().timeIntervalSince1970)-\(arc4random())"

/// 添加回调
tcpClient?.addCallback(key, callback: { (address, bytes, statusCode) in
    
    print("收到 \(address.ip):\(address.port) 数据")
    print(statusCode)
    print(bytes)
})

/// 发送信息
let bytes: [UInt8] = [1,2,3,4,5,6]
tcpClient?.sendBytes(bytes, statusCode: { (statusCode) in
    if statusCode == bytes.count {
        
        print("发送完成")
    }
})

/// 删除回调
tcpClient?.removeCallback(key)
/// 删除所有回调
tcpClient?.removeAllCallback()
/// 关闭Socket
tcpClient?.cancel()
```

##### `TCPServer`

```swift
/// 自动端口
let tcpServer = TCPServer.default()
/// 指定端口
let tcpServer = TCPServer.default(8888)
/// 绑定
if tcpServer?.bindAddress() != 0 {
    
    print("绑定失败")
}

/* 绑定成功后 */

/// 监听客户端连接
tcpServer?.listenClientConnect()


var clientAddress: Address?
/// 回调KEY
let key = "\(Date.init().timeIntervalSince1970)-\(arc4random())"

/// 添加回调
tcpServer?.addCallback(key, callback: { (address, bytes, statusCode) in
    
    if bytes.count == 0, statusCode > 0 {
        
        clientAddress = address
        print("收到客户 \(address.ip):\(address.port) 连接")
    }
    print("收到客户 \(address.ip):\(address.port) 数据")
    print(statusCode)
    print(bytes)
    
})

/* 获取客户地址后 */

/// 发送信息
let bytes: [UInt8] = [1,2,3,4,5,6]
tcpServer?.sendClient(clientAddress!, bytes: bytes, statusCode: { (statusCode) in
    if statusCode == bytes.count {
        
        print("发送完成")
    }
})

/// 删除客户
tcpServer?.removeClient(clientAddress!)
/// 删除所有客户
tcpServer?.removeAllClient()

/// 删除回调
tcpServer?.removeCallback(key)
/// 删除所有回调
tcpServer?.removeAllCallback()
/// 关闭Socket
tcpServer?.cancel()
```