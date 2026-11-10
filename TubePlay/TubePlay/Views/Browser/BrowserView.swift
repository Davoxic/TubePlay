import SwiftUI
import WebKit

public struct BrowserView: View {
    @ObservedObject var playerEngine = YouTubePlayerEngine.shared
    
    @State private var urlString: String = "https://m.youtube.com"
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var isLoading: Bool = false
    @State private var isDesktopMode: Bool = true
    
    @State private var webView = BrowserWKWebView()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Browser Navigation Header
                HStack(spacing: 10) {
                    Button(action: {
                        webView.goBack()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(canGoBack ? .primary : .secondary.opacity(0.4))
                    }
                    .disabled(!canGoBack)
                    
                    Button(action: {
                        webView.goForward()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(canGoForward ? .primary : .secondary.opacity(0.4))
                    }
                    .disabled(!canGoForward)
                    
                    // Address Bar
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                        
                        TextField("Enter URL or search YouTube...", text: $urlString)
                            .font(.system(size: 13))
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .onSubmit {
                                loadUrl(urlString)
                            }
                        
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Button(action: {
                                webView.reload()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    
                    // Desktop / Mobile toggle
                    Button(action: {
                        toggleDesktopMode()
                    }) {
                        Image(systemName: isDesktopMode ? "desktopcomputer" : "iphone")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isDesktopMode ? .red : .secondary)
                            .padding(6)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                // Browser Background Audio Banner
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("Background Audio Active • Locks screen will keep playing like Brave")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                
                // Browser WKWebView
                BrowserWebViewRepresentable(
                    webView: webView,
                    urlString: $urlString,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    isLoading: $isLoading
                )
            }
            .navigationTitle("Browser Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            loadUrl("https://www.youtube.com")
                        }) {
                            Label("YouTube Home", systemImage: "house")
                        }
                        Button(action: {
                            loadUrl("https://m.youtube.com/feed/trending")
                        }) {
                            Label("Trending", systemImage: "flame")
                        }
                        Button(action: {
                            loadUrl("https://music.youtube.com")
                        }) {
                            Label("YouTube Music", systemImage: "music.note")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                AudioSessionManager.shared.configureAudioSession()
                if webView.url == nil {
                    loadUrl(urlString)
                }
            }
        }
    }
    
    private func loadUrl(_ text: String) {
        var formatted = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !formatted.lowercased().hasPrefix("http://") && !formatted.lowercased().hasPrefix("https://") {
            if formatted.contains(".") && !formatted.contains(" ") {
                formatted = "https://" + formatted
            } else if let encoded = formatted.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                formatted = "https://www.youtube.com/results?search_query=\(encoded)"
            }
        }
        urlString = formatted
        if let targetUrl = URL(string: formatted) {
            webView.load(URLRequest(url: targetUrl))
        }
    }
    
    private func toggleDesktopMode() {
        isDesktopMode.toggle()
        if isDesktopMode {
            webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        } else {
            webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        }
        webView.reload()
    }
}

// Custom WKWebView with inline playback and visibility override scripts
public class BrowserWKWebView: WKWebView {
    init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Inject background script
        if let scriptPath = Bundle.main.path(forResource: "BackgroundPlaybackScript", ofType: "js"),
           let scriptSource = try? String(contentsOfFile: scriptPath, encoding: .utf8) {
            let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            configuration.userContentController.addUserScript(userScript)
        }
        
        super.init(frame: .zero, configuration: configuration)
        // Desktop user agent default for background play
        self.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public struct BrowserWebViewRepresentable: UIViewRepresentable {
    let webView: BrowserWKWebView
    @Binding var urlString: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: BrowserWebViewRepresentable
        
        init(_ parent: BrowserWebViewRepresentable) {
            self.parent = parent
        }
        
        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            updateNavState(webView)
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            updateNavState(webView)
            // Ensure audio session is active
            AudioSessionManager.shared.configureAudioSession()
        }
        
        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            updateNavState(webView)
        }
        
        private func updateNavState(_ webView: WKWebView) {
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            if let currentUrl = webView.url?.absoluteString {
                parent.urlString = currentUrl
            }
        }
    }
}
