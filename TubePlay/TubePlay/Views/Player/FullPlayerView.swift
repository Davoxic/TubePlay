import SwiftUI

public struct FullPlayerView: View {
    @ObservedObject var playerEngine = YouTubePlayerEngine.shared
    @ObservedObject var sleepTimer = SleepTimerManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var isScrubbing: Bool = false
    @State private var scrubTime: Double = 0
    @State private var showSleepTimerSheet: Bool = false
    @State private var showSpeedMenu: Bool = false
    
    let speedOptions: [Double] = [0.75, 1.0, 1.25, 1.5, 2.0]
    
    public init() {}
    
    public var body: some View {
        guard let video = playerEngine.currentVideo else {
            return AnyView(
                VStack {
                    Text("No Video Selected")
                    Button("Close") { dismiss() }
                }
            )
        }
        
        let displayCurrent = isScrubbing ? scrubTime : playerEngine.currentTime
        let displayDuration = playerEngine.duration
        
        return AnyView(
            NavigationStack {
                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(10)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text("NOW PLAYING")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(video.channelTitle)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showSleepTimerSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: sleepTimer.isRunning ? "moon.fill" : "moon")
                                    .font(.system(size: 16))
                                    .foregroundColor(sleepTimer.isRunning ? .purple : .primary)
                                if sleepTimer.isRunning {
                                    Text(sleepTimer.formattedRemainingTime)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.purple)
                                }
                            }
                            .padding(8)
                            .background(sleepTimer.isRunning ? Color.purple.opacity(0.15) : Color.clear)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Video Display Area (16:9 ratio)
                            ZStack {
                                PlayerWebView()
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(16 / 9, contentMode: .fit)
                                    .background(Color.black)
                                    .cornerRadius(14)
                                    .clipped()
                                
                                if playerEngine.isBuffering {
                                    ProgressView()
                                        .scaleEffect(1.3)
                                        .tint(.white)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            
                            // Title & Channel & Favorite Button
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(video.title)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                    
                                    Text(video.channelTitle)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    playerEngine.toggleFavorite(video: video)
                                }) {
                                    Image(systemName: playerEngine.isFavorite(video: video) ? "heart.fill" : "heart")
                                        .font(.system(size: 22))
                                        .foregroundColor(playerEngine.isFavorite(video: video) ? .red : .secondary)
                                        .padding(8)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Progress Slider & Timestamps
                            VStack(spacing: 6) {
                                Slider(
                                    value: Binding(
                                        get: { isScrubbing ? scrubTime : playerEngine.currentTime },
                                        set: { newValue in
                                            scrubTime = newValue
                                        }
                                    ),
                                    in: 0...max(displayDuration, 1.0),
                                    onEditingChanged: { editing in
                                        isScrubbing = editing
                                        if !editing {
                                            playerEngine.seek(to: scrubTime)
                                        }
                                    }
                                )
                                .tint(.red)
                                
                                HStack {
                                    Text(formatTime(displayCurrent))
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(displayDuration > 0 ? formatTime(displayDuration) : "--:--")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Main Playback Controls
                            HStack(spacing: 28) {
                                // Loop mode button
                                Button(action: {
                                    playerEngine.cycleLoopMode()
                                }) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "repeat")
                                            .font(.system(size: 20))
                                            .foregroundColor(playerEngine.loopMode == .off ? .secondary : .red)
                                        
                                        if playerEngine.loopMode == .one {
                                            Text("1")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.red)
                                                .offset(x: 5, y: -4)
                                        }
                                    }
                                    .frame(width: 32, height: 32)
                                }
                                
                                // Rewind 15s
                                Button(action: {
                                    playerEngine.seekRelative(delta: -15)
                                }) {
                                    Image(systemName: "gobackward.15")
                                        .font(.system(size: 26))
                                        .foregroundColor(.primary)
                                }
                                
                                // Big Play / Pause Button
                                Button(action: {
                                    playerEngine.togglePlayPause()
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 68, height: 68)
                                            .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
                                        
                                        Image(systemName: playerEngine.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.white)
                                            .offset(x: playerEngine.isPlaying ? 0 : 2)
                                    }
                                }
                                
                                // Forward 15s
                                Button(action: {
                                    playerEngine.seekRelative(delta: 15)
                                }) {
                                    Image(systemName: "goforward.15")
                                        .font(.system(size: 26))
                                        .foregroundColor(.primary)
                                }
                                
                                // Playback Speed Menu
                                Menu {
                                    ForEach(speedOptions, id: \.self) { speed in
                                        Button(action: {
                                            playerEngine.setRate(speed)
                                        }) {
                                            HStack {
                                                Text(String(format: "%.2fx", speed))
                                                if playerEngine.playbackRate == speed {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    Text(String(format: "%.2fx", playerEngine.playbackRate))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(playerEngine.playbackRate == 1.0 ? .secondary : .red)
                                        .frame(width: 44, height: 32)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.vertical, 8)
                            
                            // Background Playback Active Banner
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                
                                Text("Screen-Off Audio Playback Active")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 14))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(10)
                            .padding(.horizontal, 20)
                            
                            // Up Next Queue Section
                            if !playerEngine.queue.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("UP NEXT (\(playerEngine.queue.count))")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    ForEach(Array(playerEngine.queue.prefix(3))) { nextVid in
                                        HStack(spacing: 10) {
                                            AsyncImage(url: nextVid.thumbnailUrl) { phase in
                                                if let img = phase.image {
                                                    img.resizable().aspectRatio(contentMode: .fill)
                                                } else {
                                                    Rectangle().fill(Color.gray.opacity(0.3))
                                                }
                                            }
                                            .frame(width: 60, height: 34)
                                            .cornerRadius(4)
                                            .clipped()
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(nextVid.title)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .lineLimit(1)
                                                Text(nextVid.channelTitle)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Button("Play") {
                                                playerEngine.loadAndPlay(video: nextVid)
                                            }
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.red)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
                .navigationBarHidden(true)
                .sheet(isPresented: $showSleepTimerSheet) {
                    SleepTimerSheet()
                }
            }
        )
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
}
