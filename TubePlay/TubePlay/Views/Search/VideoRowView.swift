import SwiftUI

public struct VideoRowView: View {
    let video: YouTubeVideo
    let isCurrentPlaying: Bool
    let onSelect: () -> Void
    let onAddToQueue: () -> Void
    let onToggleFavorite: () -> Void
    let isFavorite: Bool
    
    public init(
        video: YouTubeVideo,
        isCurrentPlaying: Bool,
        isFavorite: Bool,
        onSelect: @escaping () -> Void,
        onAddToQueue: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void
    ) {
        self.video = video
        self.isCurrentPlaying = isCurrentPlaying
        self.isFavorite = isFavorite
        self.onSelect = onSelect
        self.onAddToQueue = onAddToQueue
        self.onToggleFavorite = onToggleFavorite
    }
    
    public var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 14) {
                // Thumbnail with Duration Overlay
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: video.thumbnailUrl) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.4))
                                .overlay(
                                    Image(systemName: "video.fill")
                                        .foregroundColor(.white.opacity(0.6))
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 120, height: 68)
                    .clipped()
                    .cornerRadius(8)
                    
                    // Duration badge
                    if !video.durationString.isEmpty {
                        Text(video.durationString)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(4)
                            .padding(4)
                    }
                    
                    // Now playing indicator
                    if isCurrentPlaying {
                        ZStack {
                            Color.black.opacity(0.5)
                            Image(systemName: "waveform")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.red)
                        }
                        .frame(width: 120, height: 68)
                        .cornerRadius(8)
                    }
                }
                
                // Video Metadata
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isCurrentPlaying ? .red : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(video.channelTitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        if !video.viewCountString.isEmpty {
                            Text(video.viewCountString)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        if !video.publishedTimeString.isEmpty {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(video.publishedTimeString)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Context Menu Button
                Menu {
                    Button(action: onSelect) {
                        Label("Play Now", systemImage: "play.fill")
                    }
                    Button(action: onAddToQueue) {
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    Button(action: onToggleFavorite) {
                        Label(isFavorite ? "Remove from Favorites" : "Add to Favorites",
                              systemImage: isFavorite ? "heart.slash" : "heart.fill")
                    }
                    ShareLink(item: video.watchUrl) {
                        Label("Share Video", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
