import SwiftUI

public struct SettingsView: View {
    @ObservedObject var playerEngine = YouTubePlayerEngine.shared
    @State private var adBlockEnabled: Bool = true
    @State private var autoSkipAds: Bool = true
    @State private var audioSessionStatus: String = "Active"
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // Section 1: Background Playback Status
                Section(header: Text("Background Playback Engine")) {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Audio Session: \(audioSessionStatus)")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Plays continuously when screen is locked or app is closed")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Button(action: {
                        let success = AudioSessionManager.shared.configureAudioSession()
                        audioSessionStatus = success ? "Active (Reconfigured)" : "Error"
                    }) {
                        Label("Re-test Audio Session", systemImage: "waveform.circle")
                            .font(.system(size: 14))
                    }
                }
                
                // Section 2: Browser & Ad Blocking
                Section(header: Text("Playback Options")) {
                    Toggle("Block Video & Banner Ads", isOn: $adBlockEnabled)
                    Toggle("Auto-Skip Sponsored Ads", isOn: $autoSkipAds)
                }
                
                // Section 3: How Screen-Off Playback Works
                Section(header: Text("How Screen-Off Works")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "1.circle.fill")
                                .foregroundColor(.red)
                            Text("Start any video in the Search tab or Browser tab.")
                                .font(.system(size: 13))
                        }
                        
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "2.circle.fill")
                                .foregroundColor(.red)
                            Text("Press the Power button to lock your iPhone screen, or swipe up to switch to another app.")
                                .font(.system(size: 13))
                        }
                        
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "3.circle.fill")
                                .foregroundColor(.red)
                            Text("The audio continues playing seamlessly. Use your Lock Screen widget, Apple Watch, or AirPods to pause, play, and skip 15 seconds.")
                                .font(.system(size: 13))
                        }
                    }
                    .padding(.vertical, 6)
                }
                
                // Section 4: Lock Screen Controls Info
                Section(header: Text("Lock Screen & Control Center")) {
                    HStack {
                        Image(systemName: "lock.applewatch")
                            .foregroundColor(.blue)
                        Text("Apple Watch & AirPods Controls")
                        Spacer()
                        Text("Supported")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Image(systemName: "airplayaudio")
                            .foregroundColor(.blue)
                        Text("AirPlay & Bluetooth Streaming")
                        Spacer()
                        Text("Supported")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                }
                
                // Section 5: About
                Section(header: Text("About TubePlay")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0 (Native iOS)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Engine")
                        Spacer()
                        Text("WebKit + AVAudioSession + MPNowPlaying")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
