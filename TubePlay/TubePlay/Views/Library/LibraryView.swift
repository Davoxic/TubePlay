import SwiftUI

public struct LibraryView: View {
    @ObservedObject var playerEngine = YouTubePlayerEngine.shared
    @State private var selectedTab: Int = 0 // 0: Favorites, 1: History
    
    private let storage = StorageManager.shared
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment Picker
                Picker("Library Mode", selection: $selectedTab) {
                    Text("Favorites (\(playerEngine.favorites.count))").tag(0)
                    Text("History (\(playerEngine.history.count))").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                Divider()
                
                if selectedTab == 0 {
                    favoritesView
                } else {
                    historyView
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == 1 && !playerEngine.history.isEmpty {
                        Button("Clear") {
                            storage.clearHistory()
                            playerEngine.history = []
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    // Favorites List
    private var favoritesView: some View {
        Group {
            if playerEngine.favorites.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("No Favorites Yet")
                        .font(.system(size: 18, weight: .bold))
                    Text("Tap the heart icon on any video to save it here for quick background listening.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(playerEngine.favorites) { video in
                        VideoRowView(
                            video: video,
                            isCurrentPlaying: playerEngine.currentVideo?.id == video.id,
                            isFavorite: true,
                            onSelect: {
                                playerEngine.loadAndPlay(video: video)
                            },
                            onAddToQueue: {
                                playerEngine.queue.append(video)
                            },
                            onToggleFavorite: {
                                playerEngine.toggleFavorite(video: video)
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let video = playerEngine.favorites[index]
                            playerEngine.toggleFavorite(video: video)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // History List
    private var historyView: some View {
        Group {
            if playerEngine.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("No Play History")
                        .font(.system(size: 18, weight: .bold))
                    Text("Videos you play will appear here so you can easily replay them.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(playerEngine.history) { video in
                        VideoRowView(
                            video: video,
                            isCurrentPlaying: playerEngine.currentVideo?.id == video.id,
                            isFavorite: playerEngine.isFavorite(video: video),
                            onSelect: {
                                playerEngine.loadAndPlay(video: video)
                            },
                            onAddToQueue: {
                                playerEngine.queue.append(video)
                            },
                            onToggleFavorite: {
                                playerEngine.toggleFavorite(video: video)
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}
