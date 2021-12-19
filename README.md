# Network

一个简易的`Swift`语言`Network`

包含`HTTP``Socket``Image`

### 支持

##### `HTTP` 
* 多方同一个请求，只请求一次，多方返回。
* `Disk`磁盘存储

##### `Image`
* 基于`HTTP`
* 图片缓存
* 支持GIF、TIFF动图加载
* 扩展`UIImageView`、`UIButton`、`UIBarItem`、`UITabBarItem`图片加载
* `GIFImageView`占用少量内存播放`GIF`

##### `Socket`
* 多方同一个请求，只请求一次，多方返回。
* `TCP`返回数据预处理

## Integration

### Xcode
    File -> Swift Packages -> Add Package dependency

### CocoaPods

[GitHub Network](https://github.com/VeryLoveLoli/Network)

## 使用

### `HTTP`

如果闭包包含`self`,加上`[weak self]`

```swift
        
        /// 证书设置（如不需要认证可不设置）
        /*
        Network.default.sessionDelegate.authChallenge = { challenge in
            /// 证书处理代码。。。
            
            return (.performDefaultHandling, nil)
        }
        
        Network.default.sessionDelegate.taskAuthChallenge = { task, challenge in
            /// 证书处理代码。。。
            
            return (.performDefaultHandling, nil)
        }
        */
        
        let request = URLRequest(url: URL(string: "http://i0.hdslb.com/bfs/archive/24e031e495699e234526586deb80c65d337cbe4d.png")!)
        
        /// 数据
        Network.default.data(request) { data in
            
        } error: { error in
            
        }?.resume()
        
        /// 下载
        Network.default.download(request) { path in
            
        } progress: { current, total in
            
        } error: { error in
            
        }?.resume()
        
        /// 自定义请求、回调（一般使用数据和下载即可）
        Network.default.load(request, key: Network.key(request)!, callbackKey: "\(arc4random())") { data in
            
        } path: { path in
            
        } progress: { current, total in
            
        } error: { error in
            
        }?.resume()
```

项目中使用最好先扩展 `Network`，实现项目特有的`URLRequest`请求、`Data`数据解析

### `Image`

如果闭包包含`self`,加上`[weak self]`

`UIImageView`图片加载

```swift
        let imageView = UIImageView()
        imageView.load("http://i0.hdslb.com/bfs/archive/24e031e495699e234526586deb80c65d337cbe4d.png")
```

`UIImageView`图片加载进度

```swift
        let imageView = UIImageView()
        imageView.load("http://i0.hdslb.com/bfs/archive/24e031e495699e234526586deb80c65d337cbe4d.png", progress:{ current, total in
            print("\(current)/\(total)")
        })
      
```

图片预加载

```swift
        let request = URLRequest(url: URL(string: "http://i0.hdslb.com/bfs/archive/24e031e495699e234526586deb80c65d337cbe4d.png")!)
        Image.load(request)
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

##### `TCP`

`TCP`支持数据预处理，收集足够数据，解析完成后再回调。

继承 `TCPSocketBytesProcess` 实现读取处理方法，将处理对象设置到`TCP.bytesProcess`上。

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
