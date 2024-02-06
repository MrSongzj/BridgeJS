//
//  ViewController.swift
//  BridgeJS
//
//  Created by MrSongzj on 02/06/2024.
//  Copyright (c) 2024 MrSongzj. All rights reserved.
//

import UIKit
import WebKit
import BridgeJS


class BaseJSApi: BridgeJSApiMap {
    var apiMap: [String : Any] {
        ["testSync": testSync,
         "testAsync": testAsync
        ]
    }

    func testSync(data: String) -> String {
        print("\(#function) data from js: \(data)")
        return "native-\(data)"
    }

    func testAsync(data: String, callback: @escaping (String, Bool) -> Void) {
        print("\(#function) data from js: \(data)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            callback("native-\(data)", true)
        }
    }

}

class ViewController: UIViewController {
    let wkWebView = WKWebView()
    let bridge = BridgeJS()

    override func viewDidLoad() {
        super.viewDidLoad()

        wkWebView.frame = view.bounds
        view.addSubview(wkWebView)

        // 获取 HTML 文件的 URL
        if let htmlPath = Bundle.main.path(forResource: "test", ofType: "html") {
            let htmlURL = URL(fileURLWithPath: htmlPath)
            // 加载 HTML 文件
            let baseUrl = Bundle.main.bundleURL
            wkWebView.loadFileURL(htmlURL, allowingReadAccessTo: baseUrl)
        }

        bridge.bind(to: wkWebView)
        bridge.addApi(BaseJSApi())
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

