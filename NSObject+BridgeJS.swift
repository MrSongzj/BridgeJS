//
//  NSObject+BridgeJS.swift
//  BridgeJS
//
//  Created by MrSong on 2024/2/8.
//

import Foundation
import WebKit

var associatedObjectKey: UInt8 = 0
typealias HookMethod = (_ webView: WKWebView, _ prompt: String, _ defaultText: String?, _ frame: WKFrameInfo, _ completionHandler: @escaping (String?) -> Void) -> Bool
extension NSObject {
    func ms_hookWKUIDelegate(with closure: HookMethod?) {
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
    @objc private func ms_hook_webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        // 闭包存在说明方法已经被替换
        if let closure = objc_getAssociatedObject(self, &associatedObjectKey) as? HookMethod {
            if !closure(webView, prompt, defaultText, frame, completionHandler) {
                // hook 方法不处理, 使用原方法处理
                ms_hook_webView(webView, runJavaScriptTextInputPanelWithPrompt: prompt, defaultText: defaultText, initiatedByFrame: frame, completionHandler: completionHandler)
            }
        } else {
            completionHandler(nil)
        }
    }

    /// 默认实现, 和不实现协议方法一样的效果
    @objc private func ms_default_webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        completionHandler(nil)
    }
}
