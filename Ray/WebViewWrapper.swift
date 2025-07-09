//
//  WebView.swift
//  Ray
//
//  Created by Janosch Hussain on 03/07/2025.
//

// WebView.swift
import SwiftUI
import WebKit

struct WebViewWrapper: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
