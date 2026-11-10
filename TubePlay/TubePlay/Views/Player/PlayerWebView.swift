import SwiftUI
import WebKit

public struct PlayerWebView: UIViewRepresentable {
    @ObservedObject var playerEngine = YouTubePlayerEngine.shared
    
    public init() {}
    
    public func makeUIView(context: Context) -> WKWebView {
        return playerEngine.webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        // The webView is owned and managed by YouTubePlayerEngine
    }
}
