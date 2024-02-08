//
//  BridgeJSApiMap.swift
//  BridgeJS
//
//  Created by MrSong on 2024/2/8.
//

import Foundation

/// 桥接接口映射协议
public protocol BridgeJSApiMap {
    /// 接口映射, [方法名: 方法实现(闭包/函数地址)]
    var apiMap: [String: Any] { get }

    /// 同步方法示例
    /// 只支持以下类型的同步方法

    /// 无参无返回值
    func tSyncNN()
    /// 无参有返回值
    func tSyncNY() -> String
    /// 有参无返回值
    func tSyncYN(data: String)
    /// 有参有返回值
    func tSyncYY(data: String) -> String

    /// 异步方法示例
    /// 只支持以下类型的一部方法

    /// 无参有返回值
    func tAsyncNY(callback: @escaping (_ res: String, _ complete: Bool) -> Void)
    /// 有参有返回值
    func tAsyncYY(data: String, callback: @escaping (_ res: String, _ complete: Bool) -> Void)
}

public extension BridgeJSApiMap {
    func tSyncNN() {}
    func tSyncNY() -> String {""}
    func tSyncYN(data: String) {}
    func tSyncYY(data: String) -> String {""}
    func tAsyncNY(callback: @escaping (_ res: String, _ complete: Bool) -> Void) {}
    func tAsyncYY(data: String, callback: @escaping (_ res: String, _ complete: Bool) -> Void) {}
}
