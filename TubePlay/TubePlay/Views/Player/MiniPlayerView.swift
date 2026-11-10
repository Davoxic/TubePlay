import SwiftUI

public struct MiniPlayerView: View {
    @ObservedObject var playerEngine = YouTubePlayerEngine.shared
    
    public init() {}
    
    public var body: some View {
        guard let video = playerEngine.currentVideo else {
            return AnyView(EmptyView())
        }
        
        let progress: Double = playerEngine.duration > 0 ? (playerEngine.currentTime / playerEngine.duration) : 0
        
        return AnyView(
            VStack(spacing: 0) {
                // Mini Player Content
                HStack(spacing: 12) {
                    // Small Thumbnail
                    AsyncImage(url: video.thumbnailUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .foregroundColor(.white.opacity(0.6))
                                        .font(.system(size: 14))
                                )
                        }
                    }
                    .frame(width: 46, height: 46)
                    .cornerRadius(6)
                    .clipped()
                    
                    // Video info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(video.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        Text(video.channelTitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Controls
                    HStack(spacing: 16) {
                        // Play / Pause button
                        Button(action: {
                            playerEngine.togglePlayPause()
                        }) {
                            Image(systemName: playerEngine.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                                .frame(width: 32, height: 32)
                        }
                        
                        // Skip 15s forward
                        Button(action: {
                            playerEngine.seekRelative(delta: 15)
                        }) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .contentShape(Rectangle())
                .onTapGesture {
                    playerEngine.isFullPlayerPresented = true
                }
                
                // Thin Bottom Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 2.5)
                        
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: max(0, min(geo.size.width * CGFloat(progress), geo.size.width)), height: 2.5)
                    }
                }
                .frame(height: 2.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
            .padding(.horizontal, 10)
            .padding(.bottom, 2)
        )
    }
}
