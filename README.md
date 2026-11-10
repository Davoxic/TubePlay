# TubePlay - iOS YouTube Background & Offscreen Audio Player

[![Build Unsigned IPA](https://github.com/Davoxic/TubePlay/actions/workflows/build-ipa.yml/badge.svg)](https://github.com/Davoxic/TubePlay/actions/workflows/build-ipa.yml)
[![GitHub Release](https://img.shields.io/github/v/release/Davoxic/TubePlay?color=red)](https://github.com/Davoxic/TubePlay/releases/latest)

**TubePlay** is a native iOS application built with **Swift and SwiftUI** that lets you search YouTube videos and play them continuously with the screen turned off, exactly like mobile browsers (Brave, Safari desktop mode) or dedicated music apps.

### 📥 Direct Downloads & Links
- **GitHub Repository**: [https://github.com/Davoxic/TubePlay](https://github.com/Davoxic/TubePlay)
- **GitHub Releases Page**: [https://github.com/Davoxic/TubePlay/releases/tag/v1.0.0](https://github.com/Davoxic/TubePlay/releases/tag/v1.0.0)
- **Download Unsigned IPA**: [**TubePlay-unsigned.ipa**](https://github.com/Davoxic/TubePlay/releases/download/v1.0.0/TubePlay-unsigned.ipa)
- **Local Workspace Copy**: `TubePlay-unsigned.ipa` (in project root)

---

## Key Features

- **Screen-Off Background Playback**: Turn off your iPhone display or switch apps; audio never cuts out.
- **Lock Screen & Control Center Integration**: Full `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` support. See track title, channel name, high-res artwork, elapsed time, and scrubber bar on the iOS Lock Screen, Dynamic Island, Apple Watch, and CarPlay.
- **Hardware & Headphone Controls**: Play, pause, and skip 15 seconds using AirPods stem clicks, Apple Watch, or car stereo controls.
- **YouTube Search & Autocomplete**: Real-time autocomplete suggestions, category pills (Lofi, Focus, Chill, Sleep, Podcasts, Top Hits), and direct YouTube URL / Video ID detection.
- **"Browser Mode" (Like the Browser)**: A built-in web tab that loads full YouTube with Desktop Safari user-agent spoofing, custom ad-blocking CSS, and auto-skip for sponsored segments.
- **Floating Mini-Player**: Docked above the bottom navigation bar for browsing while listening, expandable into a full-screen player with one tap.
- **Sleep Timer**: Built-in 15m, 30m, 45m, 60m countdown timer that gently stops playback when you fall asleep.
- **Local Library**: Favorites (bookmarks) and Play History saved locally with zero tracking.

---

## Technical Architecture: How Background Playback Works on iOS

Playing YouTube videos with the screen locked on iOS requires overcoming three major Apple and WebKit constraints:

```
┌────────────────────────────────────────────────────────────────────────┐
│                          TUBEPLAY ARCHITECTURE                         │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  [1] Info.plist Capabilities                                           │
│      └─ UIBackgroundModes: ["audio"]                                   │
│                                                                        │
│  [2] AVAudioSessionManager                                             │
│      ├─ Category: .playback                                            │
│      ├─ Mode: .moviePlayback                                           │
│      └─ Options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP] │
│                                                                        │
│  [3] WKWebView & JavaScript Injections (BackgroundPlaybackScript.js)   │
│      ├─ document.visibilityState  ──> permanently "visible"           │
│      ├─ document.hidden           ──> permanently false               │
│      ├─ visibilitychange & blur   ──> stopImmediatePropagation()      │
│      └─ Ad blocker & auto-skip    ──> clicks skip button automatically│
│                                                                        │
│  [4] Media Remote Controls (NowPlayingManager)                         │
│      ├─ MPNowPlayingInfoCenter (Artwork, Title, Channel, Duration)     │
│      └─ MPRemoteCommandCenter (Play, Pause, Scrub, +/-15s, Next)       │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

1. **`UIBackgroundModes` with `audio`**: Declares to iOS that this app is an authorized background audio player.
2. **`AVAudioSession` Category `.playback`**: Informs the iOS audio daemon that the app's audio stream is intentional and must not be terminated when the screen is locked or the silent switch is engaged.
3. **Overriding Page Visibility API**: YouTube uses `document.hidden` and `document.visibilityState` to deliberately pause media when Safari loses focus. Our injected script (`BackgroundPlaybackScript.js`) overrides these properties to always return `false` and `"visible"`, while silencing `visibilitychange`, `blur`, and `pagehide` events.
4. **Desktop User-Agent**: We configure `WKWebView.customUserAgent` to Desktop Safari on macOS. YouTube serves the standard desktop HTML5 media player, bypassing mobile app redirect prompts and mobile visibility pauses.
5. **Bidirectional Native Bridge**: A `WKScriptMessageHandler` (`tubePlayBridge`) reports current time, duration, and play/pause state from JavaScript to native Swift, which updates `MPNowPlayingInfoCenter` on the lock screen.

---

## Project Structure

```
TubePlay/
├── TubePlay.xcodeproj/                 # Xcode 15/16 Project with shared scheme
├── TubePlay/
│   ├── App/
│   │   ├── TubePlayApp.swift           # Main SwiftUI @main entry point
│   │   └── AppDelegate.swift           # Sets up AVAudioSession & remote controls
│   ├── Models/
│   │   ├── YouTubeVideo.swift          # Video data model
│   │   └── SearchSuggestion.swift      # Search autocomplete model
│   ├── Services/
│   │   ├── AudioSessionManager.swift   # Manages AVAudioSession & interruptions
│   │   ├── NowPlayingManager.swift     # Lock screen controls & artwork
│   │   ├── YouTubeSearchService.swift  # Search scraping, suggestions & fallback
│   │   ├── StorageManager.swift        # Local storage for Favorites & History
│   │   ├── SleepTimerManager.swift     # Auto-pause countdown timer
│   │   └── YouTubePlayerEngine.swift   # Main player state & WKWebView coordinator
│   ├── Scripts/
│   │   └── BackgroundPlaybackScript.js # JS injection for visibility & ad-skip
│   ├── Views/
│   │   ├── MainTabView.swift           # Root TabView with docked Mini-Player
│   │   ├── Search/
│   │   │   ├── SearchView.swift        # Search bar, category filters, results
│   │   │   ├── VideoRowView.swift      # Thumbnail card with duration & menu
│   │   │   ├── SearchBarView.swift     # Input field with clear & loading state
│   │   │   └── SuggestionsListView.swift# Autocomplete dropdown
│   │   ├── Player/
│   │   │   ├── FullPlayerView.swift    # Full-screen player sheet with scrubber
│   │   │   ├── MiniPlayerView.swift    # Floating bar above tabs
│   │   │   ├── PlayerWebView.swift     # UIViewRepresentable for WKWebView
│   │   │   └── SleepTimerSheet.swift   # Sleep timer picker
│   │   ├── Browser/
│   │   │   └── BrowserView.swift       # "Browser Mode" tab with desktop UA
│   │   ├── Library/
│   │   │   └── LibraryView.swift       # Favorites and Play History tabs
│   │   └── Settings/
│   │       └── SettingsView.swift      # Audio session diagnostics & guides
│   ├── Resources/
│   │   ├── Info.plist                  # UIBackgroundModes audio declaration
│   │   └── Assets.xcassets/            # AppIcon and AccentColor (YouTube Red)
│   └── Entitlements/
│       └── TubePlay.entitlements       # App network entitlements
├── preview/                            # Interactive Web Simulator
│   ├── index.html                      # Simulated iPhone UI
│   ├── style.css                       # Apple dark mode design
│   └── app.js                          # YouTube IFrame player & controls
├── SETUP_AND_RUN.md                    # Step-by-step setup and install instructions
└── README.md                           # This documentation
```

---

## How to Run

See [SETUP_AND_RUN.md](file:///s:/TOOLSCLAUDE/playback/SETUP_AND_RUN.md) for detailed instructions on:
- Testing the **interactive browser preview** immediately (`preview/index.html`).
- Opening and building in **Xcode** with a free Apple ID on a Mac or iOS Simulator.
- Installing on your iPhone via **AltStore** or **Sideloadly**.
