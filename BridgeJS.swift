//
//  BridgeJS.swift
//  BridgeJS
//
//  Created by songzhijian on 2024/2/6.
//

import Foundation
import WebKit

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
    func tAsyncNY(callback: @escaping BridgeJSApiResponse) {}
    func tAsyncYY(data: String, callback: @escaping BridgeJSApiResponse) {}
}

/// 接口响应回调
public typealias BridgeJSApiResponse = (_ res: String, _ complete: Bool) -> Void

public final class BridgeJS: NSObject, WKUIDelegate {
    /// 观察 WKWebView 的 uiDelegate 变化
    private var obUIDelegate: Any?
    /// 和 bridge 绑定的 webView
    private weak var webView: WKWebView?

    /// 生成回调函数的计数
    private var cbCount = 0
    /// 回调函数的映射
    private var cbMap: [String: (String) -> Void] = [:]
    /// 等待运行的 JavaScript 代码队列
    private var jsQueue: String? = ""
    /// 接口映射
    private var apiMap: [String: Any] = [:]

    public override init() {
        super.init()
        // 添加内部桥接方法
        let internalApi = InternalApi()
        internalApi.bridge = self
        addApi(internalApi)
    }

    /// 绑定 webView, 连接 native 和 JavaScript
    /// - Parameter webView: 和 bridge 绑定的 webView
    public func bind(to webView: WKWebView) {
        self.webView = webView
        hookUIDelegate(webView: webView, oldUIDelegate: nil)
        obUIDelegate = webView.observe(\.uiDelegate, options: .old) { [weak self] webView, info in
            let oldDelegate = info.oldValue ?? nil
            guard oldDelegate !== webView.uiDelegate else { return }
            self?.hookUIDelegate(webView: webView, oldUIDelegate: oldDelegate)
        }
    }

    private func hookUIDelegate(webView: WKWebView, oldUIDelegate: WKUIDelegate?) {
        // 还原旧代理的方法
        if let oldUiDelegate = oldUIDelegate,
           oldUiDelegate !== self {
            (oldUiDelegate as? NSObject)?.ms_replaceMethod(with: nil)
        }
        if let uiDelegate = webView.uiDelegate {
            // hook 新代理的方法
            (uiDelegate as? NSObject)?.ms_replaceMethod(with: { [weak self] webView, prompt, defaultText, frame, completionHandler in
                if self?.checkBridgeId(prompt) ?? false {
                    // JavaScript 调用原生方法
                    self?.webView(webView, runJavaScriptTextInputPanelWithPrompt: prompt, defaultText: defaultText, initiatedByFrame: frame, completionHandler: completionHandler)
                    return true
                }
                return false
            })
            // 添加代理方法实现后需要重新设置代理, 否则不会生效
            webView.uiDelegate = uiDelegate
        } else {
            webView.uiDelegate = self
        }
    }

    /// 添加桥接方法
    /// - Parameters:
    ///   - api: 桥接方法对象
    ///   - namespace: 命名空间
    public func addApi(_ api: BridgeJSApiMap, namespace: String = "") {
        if namespace.isEmpty {
            apiMap.merge(api.apiMap) { _, new in new }
        } else {
            // 设置命名空间, 把接口映射的 key 组装成 namespace.method
            api.apiMap.forEach { name, method in
                apiMap["\(namespace).\(name)"] = method
            }
        }
    }

    /// 调用 JavaScript 的方法
    /// - Parameters:
    ///   - method: 方法名
    ///   - data: 参数列表, 要求可以被转成 json 字符串
    ///   - completionHandler: 返回值回调, 如果 JavaScript 方法没有返回值则不会执行回调函数
    public func call(_ method: String, data: [Any]? = nil, completionHandler: ((String) -> Void)? = nil) {
        var callInfo: [String: Any] = ["method": method]
        if let data = data {
            callInfo["data"] = data
        }
        if let completionHandler = completionHandler {
            // 生成回调函数
            let callback = "mscb\(cbCount)"
            cbCount += 1
            cbMap[callback] = completionHandler
            callInfo["callback"] = callback
        }
        guard let callData = getJsonString(dictionary: callInfo) else { return }
        let js = "msNaviteCallJavaScript(\(callData));"
        // 如果存在 JavaScript 代码队列, 说明 JavaScript 环境还没有初始化完成, 先追加到队列中
        if let jsQueue = jsQueue {
            self.jsQueue = jsQueue + js
        } else {
            // 执行 JavaScript 代码
            runJs(js)
        }
    }

    public func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        guard checkBridgeId(prompt) else {
            print("runJS no call native method")
            // 不是调用原生方法, 默认返回 nil
            completionHandler(nil)
            return
        }
        // 调用原生方法
        // 解析出方法名
        let name = prompt.replacingOccurrences(of: "msbridge-", with: "")
        // 查找方法实例
        guard let method = apiMap[name] else {
            // 没有找到原生方法实现
            print("没有找到原生方法[\(name)]的实现")
            completionHandler(nil)
            return
        }
        // 解析方法调用信息
        let callInfo = defaultText != nil ? getDictionary(jsonString: defaultText!) : nil
        guard let callInfo = callInfo else {
            // 方法调用信息解析失败
            print("方法调佣信息解析失败")
            completionHandler(nil)
            return
        }
        // 参数
        let data = callInfo["data"] ?? ""
        // 调用类型
        let cb = callInfo["callback"]
        var r: String? = nil
        if let cb = cb {
            // 异步调用
            let callback: (String, Bool) -> Void = { res, complete in
                webView.evaluateJavaScript("\(cb)('\(res)');\(complete ? "delete window.\(cb)" : "");")
            }
            if let m = method as? (String, @escaping BridgeJSApiResponse) -> Void { m(data, callback) }
            else if let m = method as? (@escaping BridgeJSApiResponse) -> Void { m(callback) }
            else { print("原生方法无法被调用") }
        } else {
            // 同步调用
            // 无参无返回值
            if let m = method as? () -> Void { m() }
            // 无参有返回值
            else if let m = method as? () -> String { r = m() }
            // 有参无返回值
            else if let m = method as? (String) -> Void { m(data) }
            // 有参有返回值
            else if let m = method as? (String) -> String { r = m(data) }
            else { print("原生方法无法被调用") }
        }
        completionHandler(r)
    }

    /// 检查是否为 JavaScript 与原生通讯的情况
    private func checkBridgeId(_ string: String) -> Bool {
        string.hasPrefix("msbridge-")
    }

    /// 执行 JavaScript 代码
    /// - Parameter js: JavaScript 代码
    private func runJs(_ js: String) {
        webView?.evaluateJavaScript(js, completionHandler: { _, error in
            if let error = error {
                print("调用js方法出错: \(error)")
            }
        })
    }

    /// 把 json 字符串转成字典
    private func getDictionary(jsonString: String) -> [String: String]? {
        if let jsonData = jsonString.data(using: .utf8) {
            return (try? JSONSerialization.jsonObject(with: jsonData)) as? [String: String]
        } else {
            print("无法将字符串转换为 Data")
            return nil
        }
    }

    /// 把字典转成 json 字符串
    private func getJsonString(dictionary: [String: Any]) -> String? {
        let jsonData = try? JSONSerialization.data(withJSONObject: dictionary)
        if let jsonData = jsonData {
            return String(data: jsonData, encoding: .utf8)
        } else {
            print("无法将字典转换为 Data")
            return nil
        }
    }

    /// 内部接口
    private class InternalApi: BridgeJSApiMap {
        weak var bridge: BridgeJS!

        var apiMap: [String : Any] {
            ["_msJsCallback": _msJsCallback,
             "_init": _init]
        }

        /// JavaScript 返回值回调
        /// - Parameter arg: 回调信息
        func _msJsCallback(arg: String) {
            let callInfo = bridge.getDictionary(jsonString: arg)
            // 如果原生接收返回值
            if let callback = callInfo?["callback"],
               let cb = bridge.cbMap[callback] {
                let data = callInfo?["data"] ?? ""
                cb(data)
                // 如果返回值回调完成, 删除回调函数
                if callInfo?["complete"] != "0" {
                    bridge.cbMap[callback] = nil
                }
            }
        }

        /// JavaScript 方法开始注册, 这个时刻才可以执行 JavaScript 方法
        func _init() {
            guard let jsQueue = bridge.jsQueue else { return }
            bridge.runJs(jsQueue)
            bridge.jsQueue = nil
        }
    }
}

var associatedObjectKey: UInt8 = 0
typealias ReplaceMethod = (_ webView: WKWebView, _ prompt: String, _ defaultText: String?, _ frame: WKFrameInfo, _ completionHandler: @escaping (String?) -> Void) -> Bool
extension NSObject {
    func ms_replaceMethod(with closure: ReplaceMethod?) {
        let originalSel = #selector(WKUIDelegate.webView(_:runJavaScriptTextInputPanelWithPrompt:defaultText:initiatedByFrame:completionHandler:))

        if class_getInstanceMethod(type(of: self), originalSel) == nil {
            // 没有实现添加默认实现
            let sel = #selector(ms_default_webView(_:runJavaScriptTextInputPanelWithPrompt:defaultText:initiatedByFrame:completionHandler:))
            let imp = class_getMethodImplementation(type(of: self), sel)!
            class_addMethod(type(of: self), originalSel, imp, nil)
        }
        // 交换方法
        let originalMethod = class_getInstanceMethod(type(of: self), originalSel)!
        let hookSel = #selector(ms_hook_webView(_:runJavaScriptTextInputPanelWithPrompt:defaultText:initiatedByFrame:completionHandler:))
        let hookMethod = class_getInstanceMethod(type(of: self), hookSel)!
        method_exchangeImplementations(originalMethod, hookMethod)
        // 关联闭包对象
        objc_setAssociatedObject(self, &associatedObjectKey, closure, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    }

    /// hook 协议方法
    @objc func ms_hook_webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        // 闭包存在说明方法已经被替换
        if let closure = objc_getAssociatedObject(self, &associatedObjectKey) as? ReplaceMethod {
            if !closure(webView, prompt, defaultText, frame, completionHandler) {
                // hook 方法不处理, 使用原方法处理
                ms_hook_webView(webView, runJavaScriptTextInputPanelWithPrompt: prompt, defaultText: defaultText, initiatedByFrame: frame, completionHandler: completionHandler)
            }
        } else {
            completionHandler(nil)
        }
    }

    /// 默认实现, 和不实现协议方法一样的效果
    @objc func ms_default_webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        completionHandler(nil)
    }
}
