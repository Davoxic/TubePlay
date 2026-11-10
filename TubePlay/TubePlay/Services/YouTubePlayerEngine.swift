import Foundation
import WebKit
import Combine
import SwiftUI

public enum LoopMode: String, CaseIterable {
    case off = "Off"
    case one = "Loop Current"
    case all = "Loop Queue"
}

public enum PlayerDisplayMode: String, CaseIterable {
    case direct = "Direct Player (No Error 152-4)"
    case embed = "Embedded Player"
}

public final class YouTubePlayerEngine: NSObject, ObservableObject {
    public static let shared = YouTubePlayerEngine()
    
    // Published State for SwiftUI UI
    @Published public var currentVideo: YouTubeVideo?
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var playbackRate: Double = 1.0
    @Published public var loopMode: LoopMode = .off
    @Published public var playerDisplayMode: PlayerDisplayMode = .direct
    @Published public var isMiniPlayerVisible: Bool = false
    @Published public var isFullPlayerPresented: Bool = false
    @Published public var isBuffering: Bool = false
    
    // Queue & Playlists
    @Published public var queue: [YouTubeVideo] = []
    @Published public var favorites: [YouTubeVideo] = []
    @Published public var history: [YouTubeVideo] = []
    
    // Persistent Background WKWebView
    public private(set) var webView: WKWebView!
    
    private let audioSession = AudioSessionManager.shared
    private let nowPlaying = NowPlayingManager.shared
    private let storage = StorageManager.shared
    private let sleepTimer = SleepTimerManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        setupWebView()
        setupAudioSessionHandlers()
        setupRemoteCommandHandlers()
        setupSleepTimer()
        loadPersistedData()
        setupAppLifecycleObservers()
    }
    
    // MARK: - WKWebView Setup for Background Playback
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        
        // Critical settings for background audio and inline video
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Load custom background script
        if let scriptPath = Bundle.main.path(forResource: "BackgroundPlaybackScript", ofType: "js"),
           let scriptSource = try? String(contentsOfFile: scriptPath, encoding: .utf8) {
            let userScript = WKUserScript(
                source: scriptSource,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            configuration.userContentController.addUserScript(userScript)
        } else {
            // Fallback inline script
            let fallbackScript = """
            Object.defineProperty(document, 'hidden', { get: () => false, configurable: true });
            Object.defineProperty(document, 'visibilityState', { get: () => 'visible', configurable: true });
            window.addEventListener('visibilitychange', e => e.stopImmediatePropagation(), true);
            """
            let userScript = WKUserScript(source: fallbackScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            configuration.userContentController.addUserScript(userScript)
        }
        
        // Register script message bridge
        configuration.userContentController.add(self, name: "tubePlayBridge")
        
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 375, height: 667), configuration: configuration)
        webView.navigationDelegate = self
        // Set Desktop Safari User Agent so YouTube serves standard HTML5 player without mobile pause triggers
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        self.webView = webView
    }
    
    // MARK: - Audio Session & Remote Control Handlers
    private func setupAudioSessionHandlers() {
        _ = audioSession.configureAudioSession()
        
        audioSession.onInterruptionBegan = { [weak self] in
            self?.pause()
        }
        
        audioSession.onInterruptionEnded = { [weak self] shouldResume in
            if shouldResume {
                self?.play()
            }
        }
        
        audioSession.onHeadphonesUnplugged = { [weak self] in
            self?.pause()
        }
    }
    
    private func setupRemoteCommandHandlers() {
        nowPlaying.onPlay = { [weak self] in self?.play() }
        nowPlaying.onPause = { [weak self] in self?.pause() }
        nowPlaying.onTogglePlayPause = { [weak self] in self?.togglePlayPause() }
        nowPlaying.onSkipForward = { [weak self] delta in self?.seekRelative(delta: delta) }
        nowPlaying.onSkipBackward = { [weak self] delta in self?.seekRelative(delta: -delta) }
        nowPlaying.onSeekTo = { [weak self] time in self?.seek(to: time) }
        nowPlaying.onNextTrack = { [weak self] in self?.playNext() }
        nowPlaying.onPreviousTrack = { [weak self] in self?.playPrevious() }
    }
    
    private func setupSleepTimer() {
        sleepTimer.onTimerFired = { [weak self] in
            print("TubePlay: Sleep timer fired, pausing playback")
            self?.pause()
        }
    }
    
    private func loadPersistedData() {
        favorites = storage.loadFavorites()
        history = storage.loadHistory()
    }
    
    // MARK: - App Lifecycle Notifications
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleWillEnterForeground()
            }
            .store(in: &cancellables)
    }
    
    private func handleDidEnterBackground() {
        print("TubePlay: App entered background. Keeping audio session alive...")
        _ = audioSession.configureAudioSession()
        
        // If playing, send a heartbeat to JS to ensure the video keeps running
        if isPlaying {
            webView.evaluateJavaScript("if (window.__tubePlay_play) { window.__tubePlay_play(); }")
        }
    }
    
    private func handleWillEnterForeground() {
        print("TubePlay: App entered foreground.")
        // Sync playback state
        syncStateFromWebView()
    }
    
    // MARK: - Playback Control API
    public func loadAndPlay(video: YouTubeVideo, addToQueue: Bool = false) {
        audioSession.configureAudioSession()
        
        currentVideo = video
        isMiniPlayerVisible = true
        isBuffering = true
        currentTime = 0
        duration = 0
        
        // Save to history
        history = storage.addToHistory(video)
        
        // Use Direct Watch by default: 100% video support, eliminates Error 152-4 and Error 150
        if playerDisplayMode == .direct {
            loadDirectWatch(video: video)
        } else {
            loadEmbed(video: video)
        }
        
        nowPlaying.updateNowPlaying(video: video, isPlaying: true, currentTime: 0, duration: 0)
    }
    
    /// Loads video directly from m.youtube.com (bypasses all iframe embed restrictions & Error 152-4)
    public func loadDirectWatch(video: YouTubeVideo) {
        let watchUrl = URL(string: "https://m.youtube.com/watch?v=\(video.id)")!
        var req = URLRequest(url: watchUrl)
        req.setValue("https://m.youtube.com", forHTTPHeaderField: "Referer")
        webView.load(req)
    }
    
    /// Loads embedded iframe player with strict referrer origin headers
    public func loadEmbed(video: YouTubeVideo) {
        let html = generatePlayerHTML(videoId: video.id)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com"))
    }
    
    public func togglePlayerDisplayMode() {
        if playerDisplayMode == .direct {
            playerDisplayMode = .embed
        } else {
            playerDisplayMode = .direct
        }
        if let video = currentVideo {
            if playerDisplayMode == .direct {
                loadDirectWatch(video: video)
            } else {
                loadEmbed(video: video)
            }
        }
    }
    
    public func play() {
        audioSession.configureAudioSession()
        isPlaying = true
        webView.evaluateJavaScript("window.__tubePlay_play ? window.__tubePlay_play() : (document.querySelector('video') && document.querySelector('video').play())")
        nowPlaying.updateNowPlaying(video: currentVideo, isPlaying: true, currentTime: currentTime, duration: duration)
    }
    
    public func pause() {
        isPlaying = false
        webView.evaluateJavaScript("window.__tubePlay_pause ? window.__tubePlay_pause() : (document.querySelector('video') && document.querySelector('video').pause())")
        nowPlaying.updateNowPlaying(video: currentVideo, isPlaying: false, currentTime: currentTime, duration: duration)
    }
    
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    public func seek(to seconds: Double) {
        currentTime = seconds
        webView.evaluateJavaScript("window.__tubePlay_seek ? window.__tubePlay_seek(\(seconds)) : (document.querySelector('video') && (document.querySelector('video').currentTime = \(seconds)))")
        nowPlaying.updateNowPlaying(video: currentVideo, isPlaying: isPlaying, currentTime: seconds, duration: duration)
    }
    
    public func seekRelative(delta: Double) {
        let newTime = max(0, min(currentTime + delta, duration > 0 ? duration : currentTime + delta))
        seek(to: newTime)
    }
    
    public func setRate(_ rate: Double) {
        playbackRate = rate
        webView.evaluateJavaScript("window.__tubePlay_setPlaybackRate ? window.__tubePlay_setPlaybackRate(\(rate)) : (document.querySelector('video') && (document.querySelector('video').playbackRate = \(rate)))")
    }
    
    public func cycleLoopMode() {
        switch loopMode {
        case .off: loopMode = .one
        case .one: loopMode = .all
        case .all: loopMode = .off
        }
    }
    
    public func playNext() {
        guard !queue.isEmpty else {
            if loopMode == .one, let video = currentVideo {
                seek(to: 0)
                play()
            }
            return
        }
        let nextVideo = queue.removeFirst()
        loadAndPlay(video: nextVideo)
    }
    
    public func playPrevious() {
        if currentTime > 3.0 {
            seek(to: 0)
        } else if let prevVideo = history.dropFirst().first {
            loadAndPlay(video: prevVideo)
        } else {
            seek(to: 0)
        }
    }
    
    public func toggleFavorite(video: YouTubeVideo) {
        favorites = storage.toggleFavorite(video)
    }
    
    public func isFavorite(video: YouTubeVideo) -> Bool {
        favorites.contains { $0.id == video.id }
    }
    
    public func syncStateFromWebView() {
        webView.evaluateJavaScript("window.__tubePlay_getPlaybackState ? window.__tubePlay_getPlaybackState() : null") { [weak self] result, _ in
            guard let self = self, let dict = result as? [String: Any] else { return }
            if let cur = dict["currentTime"] as? Double { self.currentTime = cur }
            if let dur = dict["duration"] as? Double, dur > 0 { self.duration = dur }
            if let paused = dict["paused"] as? Bool { self.isPlaying = !paused }
            self.nowPlaying.updateNowPlaying(video: self.currentVideo, isPlaying: self.isPlaying, currentTime: self.currentTime, duration: self.duration)
        }
    }
    
    // MARK: - HTML Player Container with IFrame API & Background bypasses
    private func generatePlayerHTML(videoId: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <meta name="referrer" content="strict-origin-when-cross-origin">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; background-color: #000; }
                html, body { width: 100%; height: 100%; overflow: hidden; background: #000; }
                #player-container { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
                iframe { width: 100%; height: 100%; border: none; }
            </style>
        </head>
        <body>
            <div id="player-container">
                <iframe id="yt-player"
                    src="https://www.youtube-nocookie.com/embed/\(videoId)?enablejsapi=1&autoplay=1&playsinline=1&controls=1&rel=0&modestbranding=1"
                    referrerpolicy="strict-origin-when-cross-origin"
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                    allowfullscreen>
                </iframe>
            </div>
            
            <script>
                // Spoof visibility state immediately inside container
                Object.defineProperty(document, 'hidden', { get: () => false, configurable: true });
                Object.defineProperty(document, 'visibilityState', { get: () => 'visible', configurable: true });
                window.addEventListener('visibilitychange', e => e.stopImmediatePropagation(), true);
                window.addEventListener('blur', e => e.stopImmediatePropagation(), true);
                window.addEventListener('pagehide', e => e.stopImmediatePropagation(), true);
                
                // Load YouTube IFrame API
                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                var firstScriptTag = document.getElementsByTagName('script')[0];
                firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
                
                var player;
                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('yt-player', {
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange,
                            'onError': onPlayerError
                        }
                    });
                }
                
                function onPlayerReady(event) {
                    event.target.playVideo();
                    postToNative({ type: 'ready' });
                }
                
                function onPlayerError(event) {
                    // Handles error 150/152/101 (embedding restricted by owner / origin mismatch)
                    postToNative({ type: 'error', code: event.data });
                }
                
                function onPlayerStateChange(event) {
                    // YT.PlayerState: PLAYING (1), PAUSED (2), BUFFERING (3), CUED (5), ENDED (0)
                    var state = event.data;
                    var cur = player.getCurrentTime ? player.getCurrentTime() : 0;
                    var dur = player.getDuration ? player.getDuration() : 0;
                    
                    if (state === 1) { // Playing
                        postToNative({ type: 'play', currentTime: cur, duration: dur });
                    } else if (state === 2) { // Paused
                        postToNative({ type: 'pause', currentTime: cur, duration: dur });
                    } else if (state === 0) { // Ended
                        postToNative({ type: 'ended', currentTime: dur, duration: dur });
                    } else if (state === 3) { // Buffering
                        postToNative({ type: 'buffering', currentTime: cur, duration: dur });
                    }
                }
                
                // Periodic time reporter
                setInterval(function() {
                    if (player && player.getPlayerState && player.getPlayerState() === 1) {
                        var cur = player.getCurrentTime();
                        var dur = player.getDuration();
                        postToNative({ type: 'timeUpdate', currentTime: cur, duration: dur });
                    }
                }, 1000);
                
                function postToNative(msg) {
                    try {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.tubePlayBridge) {
                            window.webkit.messageHandlers.tubePlayBridge.postMessage(msg);
                        }
                    } catch(e) {}
                }
                
                // Expose global Swift control functions
                window.__tubePlay_play = function() {
                    if (player && player.playVideo) player.playVideo();
                };
                window.__tubePlay_pause = function() {
                    if (player && player.pauseVideo) player.pauseVideo();
                };
                window.__tubePlay_seek = function(sec) {
                    if (player && player.seekTo) player.seekTo(sec, true);
                };
                window.__tubePlay_setPlaybackRate = function(rate) {
                    if (player && player.setPlaybackRate) player.setPlaybackRate(rate);
                };
                window.__tubePlay_getPlaybackState = function() {
                    var cur = player && player.getCurrentTime ? player.getCurrentTime() : 0;
                    var dur = player && player.getDuration ? player.getDuration() : 0;
                    var st = player && player.getPlayerState ? player.getPlayerState() : -1;
                    return { currentTime: cur, duration: dur, paused: st !== 1 };
                };
            </script>
        </body>
        </html>
        """
    }
}

// MARK: - WKScriptMessageHandler
extension YouTubePlayerEngine: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "tubePlayBridge",
              let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch type {
            case "error":
                let code = dict["code"] as? Int ?? 0
                print("TubePlay: YouTube embed error \(code) (e.g. 152-4 or 150). Auto-fallback to Direct Watch player...")
                if let video = self.currentVideo {
                    self.playerDisplayMode = .direct
                    self.loadDirectWatch(video: video)
                }
                
            case "play":
                self.isPlaying = true
                self.isBuffering = false
                if let cur = dict["currentTime"] as? Double { self.currentTime = cur }
                if let dur = dict["duration"] as? Double, dur > 0 { self.duration = dur }
                self.nowPlaying.updateNowPlaying(video: self.currentVideo, isPlaying: true, currentTime: self.currentTime, duration: self.duration)
                
            case "pause":
                self.isPlaying = false
                if let cur = dict["currentTime"] as? Double { self.currentTime = cur }
                self.nowPlaying.updateNowPlaying(video: self.currentVideo, isPlaying: false, currentTime: self.currentTime, duration: self.duration)
                
            case "timeUpdate":
                if let cur = dict["currentTime"] as? Double { self.currentTime = cur }
                if let dur = dict["duration"] as? Double, dur > 0 { self.duration = dur }
                // Throttle now playing updates on lock screen
                if Int(self.currentTime) % 5 == 0 {
                    self.nowPlaying.updateNowPlaying(video: self.currentVideo, isPlaying: self.isPlaying, currentTime: self.currentTime, duration: self.duration)
                }
                
            case "buffering":
                self.isBuffering = true
                
            case "ended":
                self.isPlaying = false
                self.handlePlaybackEnded()
                
            case "loadedMetadata":
                if let dur = dict["duration"] as? Double, dur > 0 { self.duration = dur }
                self.nowPlaying.updateNowPlaying(video: self.currentVideo, isPlaying: self.isPlaying, currentTime: self.currentTime, duration: self.duration)
                
            default:
                break
            }
        }
    }
    
    private func handlePlaybackEnded() {
        switch loopMode {
        case .one:
            seek(to: 0)
            play()
        case .all:
            if !queue.isEmpty {
                playNext()
            } else if let video = currentVideo {
                seek(to: 0)
                play()
            }
        case .off:
            if !queue.isEmpty {
                playNext()
            }
        }
    }
}

// MARK: - WKNavigationDelegate
extension YouTubePlayerEngine: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isBuffering = false
        // Trigger auto-play on mobile YouTube or embed
        webView.evaluateJavaScript("""
            if (window.__tubePlay_play) { window.__tubePlay_play(); }
            const v = document.querySelector('video');
            if (v && v.paused) { v.play().catch(()=>{}); }
            const playBtn = document.querySelector('.ytp-large-play-button, .player-control-play-pause-icon, button[aria-label="Play"], .ytm-play-button');
            if (playBtn) { playBtn.click(); }
        """)
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isBuffering = false
        print("TubePlay: WebView failed navigation: \(error.localizedDescription)")
    }
}
