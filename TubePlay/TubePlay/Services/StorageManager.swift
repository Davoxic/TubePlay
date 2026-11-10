import Foundation

public final class StorageManager {
    public static let shared = StorageManager()
    
    private let favoritesKey = "tubeplay_favorites_v1"
    private let historyKey = "tubeplay_history_v1"
    private let searchHistoryKey = "tubeplay_search_history_v1"
    
    private init() {}
    
    // MARK: - Favorites
    public func loadFavorites() -> [YouTubeVideo] {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey),
              let list = try? JSONDecoder().decode([YouTubeVideo].self, from: data) else {
            return []
        }
        return list
    }
    
    public func saveFavorites(_ favorites: [YouTubeVideo]) {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }
    
    public func isFavorite(videoId: String) -> Bool {
        let list = loadFavorites()
        return list.contains { $0.id == videoId }
    }
    
    public func toggleFavorite(_ video: YouTubeVideo) -> [YouTubeVideo] {
        var list = loadFavorites()
        if let index = list.firstIndex(where: { $0.id == video.id }) {
            list.remove(at: index)
        } else {
            list.insert(video, at: 0)
        }
        saveFavorites(list)
        return list
    }
    
    // MARK: - Play History
    public func loadHistory() -> [YouTubeVideo] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let list = try? JSONDecoder().decode([YouTubeVideo].self, from: data) else {
            return []
        }
        return list
    }
    
    public func addToHistory(_ video: YouTubeVideo) -> [YouTubeVideo] {
        var list = loadHistory()
        list.removeAll { $0.id == video.id }
        list.insert(video, at: 0)
        // Keep last 100 items
        if list.count > 100 {
            list = Array(list.prefix(100))
        }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
        return list
    }
    
    public func clearHistory() {
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
    
    // MARK: - Search History
    public func loadSearchHistory() -> [String] {
        return UserDefaults.standard.stringArray(forKey: searchHistoryKey) ?? [
            "lofi hip hop radio",
            "relaxing jazz music",
            "ambient study sounds",
            "acoustic guitar instrumental"
        ]
    }
    
    public func addSearchTerm(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = loadSearchHistory()
        list.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        list.insert(trimmed, at: 0)
        if list.count > 20 {
            list = Array(list.prefix(20))
        }
        UserDefaults.standard.set(list, forKey: searchHistoryKey)
    }
    
    public func clearSearchHistory() {
        UserDefaults.standard.removeObject(forKey: searchHistoryKey)
    }
}
