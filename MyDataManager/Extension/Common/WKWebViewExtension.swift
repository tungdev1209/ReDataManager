//
//  WKWebViewExtension.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 1/24/19.
//  Copyright © 2019 Tung Nguyen. All rights reserved.
//

import WebKit

private var kLoadHTMLCompletion: UInt8 = 0
private var kNavigationHandler: UInt8 = 0
extension WKWebView {
    typealias HTMLCompletion = (() -> Void)
    
    var loadHTMLCompletion: HTMLCompletion? {
        get {
            return objc_getAssociatedObject(self, &kLoadHTMLCompletion) as? HTMLCompletion
        }
        set(block) {
            objc_setAssociatedObject(self, &kLoadHTMLCompletion, block, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private var navigationHandler: WKNavigationDelegate? {
        get {
            return objc_getAssociatedObject(self, &kNavigationHandler) as? WKNavigationDelegate
        }
        set(handler) {
            objc_setAssociatedObject(self, &kNavigationHandler, handler, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func loadHTMLString(_ string: String, baseURL: URL?, completion: (() -> Void)?) {
        loadHTMLCompletion = completion
        navigationHandler = WebNavigationHandler()
        navigationDelegate = navigationHandler
        loadHTMLString(string, baseURL: baseURL)
    }
}

class WebNavigationHandler: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.loadHTMLCompletion?()
    }
}
