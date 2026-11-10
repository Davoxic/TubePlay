import SwiftUI

public struct SearchView: View {
    @ObservedObject var playerEngine = YouTubePlayerEngine.shared
    @State private var searchText: String = ""
    @State private var searchResults: [YouTubeVideo] = []
    @State private var suggestions: [SearchSuggestion] = []
    @State private var isSearching: Bool = false
    @State private var showSuggestions: Bool = false
    @State private var searchHistory: [String] = []
    @State private var selectedCategory: String? = nil
    
    private let searchService = YouTubeSearchService.shared
    private let storage = StorageManager.shared
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Input Bar
                SearchBarView(
                    text: $searchText,
                    isSearching: isSearching,
                    onCommit: {
                        performSearch(query: searchText)
                    },
                    onClear: {
                        suggestions = []
                        showSuggestions = false
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .onChange(of: searchText) { newValue in
                    handleSearchTextChange(newValue)
                }
                
                // Categories Horizontal Filter Scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(YouTubeSearchService.curatedCategories, id: \.title) { cat in
                            Button(action: {
                                selectedCategory = cat.title
                                searchText = cat.query
                                performSearch(query: cat.query)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 12))
                                    Text(cat.title)
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(selectedCategory == cat.title ? Color.red : Color(UIColor.secondarySystemBackground))
                                .foregroundColor(selectedCategory == cat.title ? .white : .primary)
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                
                Divider()
                
                // Content View: Suggestions OR Results OR Default Discovery
                ZStack {
                    if showSuggestions && !suggestions.isEmpty {
                        ScrollView {
                            SuggestionsListView(
                                suggestions: suggestions,
                                onSelect: { selectedText in
                                    searchText = selectedText
                                    performSearch(query: selectedText)
                                },
                                onAutoComplete: { autoText in
                                    searchText = autoText
                                }
                            )
                        }
                    } else if !searchResults.isEmpty {
                        List {
                            ForEach(searchResults) { video in
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
                    } else {
                        // Empty / Discovery Screen
                        defaultDiscoveryView
                    }
                }
            }
            .navigationTitle("TubePlay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            performSearch(query: "lofi hip hop radio")
                        }) {
                            Label("Load Lofi Stream", systemImage: "music.note")
                        }
                        Button(action: {
                            storage.clearSearchHistory()
                            searchHistory = []
                        }) {
                            Label("Clear Search History", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                searchHistory = storage.loadSearchHistory()
                if searchResults.isEmpty {
                    loadInitialSuggestions()
                }
            }
        }
    }
    
    // Default Discovery View with Search History and Quick Starters
    private var defaultDiscoveryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Recent Searches
                if !searchHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Searches")
                            .font(.system(size: 16, weight: .bold))
                            .padding(.horizontal, 16)
                        
                        LazyVStack(spacing: 0) {
                            ForEach(searchHistory.prefix(5), id: \.self) { term in
                                Button(action: {
                                    searchText = term
                                    performSearch(query: term)
                                }) {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 14))
                                        Text(term)
                                            .font(.system(size: 15))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "arrow.up.left")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 12))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                }
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                }
                
                // Recommended Starter Cards
                VStack(alignment: .leading, spacing: 10) {
                    Text("Featured Background Stations")
                        .font(.system(size: 16, weight: .bold))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 12) {
                        ForEach(YouTubeVideo.sampleList) { video in
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
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 80)
        }
    }
    
    // MARK: - Search Actions
    private func handleSearchTextChange(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestions = []
            showSuggestions = false
            return
        }
        
        showSuggestions = true
        Task {
            let fetched = await searchService.fetchSuggestions(for: trimmed)
            await MainActor.run {
                if self.searchText == text {
                    self.suggestions = fetched
                }
            }
        }
    }
    
    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        showSuggestions = false
        isSearching = true
        storage.addSearchTerm(trimmed)
        searchHistory = storage.loadSearchHistory()
        
        Task {
            let videos = await searchService.searchVideos(query: trimmed)
            await MainActor.run {
                self.searchResults = videos
                self.isSearching = false
            }
        }
    }
    
    private func loadInitialSuggestions() {
        Task {
            let videos = await searchService.searchVideos(query: "lofi hip hop beats")
            await MainActor.run {
                if self.searchResults.isEmpty {
                    self.searchResults = videos
                }
            }
        }
    }
}
