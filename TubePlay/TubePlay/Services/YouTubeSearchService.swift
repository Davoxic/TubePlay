import Foundation

public final class YouTubeSearchService {
    public static let shared = YouTubeSearchService()
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept-Language": "en-US,en;q=0.9"
        ]
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Search Autocomplete Suggestions
    public func fetchSuggestions(for query: String) async -> [SearchSuggestion] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://suggestqueries.google.com/complete/search?client=youtube&ds=yt&q=\(encoded)") else {
            return []
        }
        
        do {
            let (data, _) = try await session.data(from: url)
            // Format is: window.google.ac.h(["query",[["suggestion",0,[...]],...],{...}])
            // Or JSON array: ["query", [["s1", 0], ["s2", 0]]] or ["query", ["s1", "s2"]]
            if let string = String(data: data, encoding: .utf8) {
                return parseSuggestions(rawString: string)
            }
        } catch {
            print("TubePlay: Error fetching suggestions: \(error)")
        }
        return []
    }
    
    private func parseSuggestions(rawString: String) -> [SearchSuggestion] {
        // Strip JSONP wrapper if present: google.ac.h(...)
        var jsonText = rawString
        if let start = jsonText.range(of: "("), let end = jsonText.range(of: ")", options: .backwards) {
            jsonText = String(jsonText[start.upperBound..<end.lowerBound])
        }
        
        guard let data = jsonText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              json.count > 1 else {
            return []
        }
        
        var suggestions: [SearchSuggestion] = []
        if let array = json[1] as? [Any] {
            for item in array {
                if let str = item as? String {
                    suggestions.append(SearchSuggestion(text: str))
                } else if let subArr = item as? [Any], let firstStr = subArr.first as? String {
                    suggestions.append(SearchSuggestion(text: firstStr))
                }
            }
        }
        return suggestions
    }
    
    // MARK: - Video Search
    public func searchVideos(query: String) async -> [YouTubeVideo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        // 1. Check if user pasted a direct YouTube URL or ID
        if let directVideo = extractDirectVideo(from: trimmed) {
            return [directVideo]
        }
        
        // 2. Try primary web search scrape (no API key required)
        if let results = await searchViaYouTubeWeb(query: trimmed), !results.isEmpty {
            return results
        }
        
        // 3. Try Invidious Public API fallback
        if let fallbackResults = await searchViaInvidious(query: trimmed), !fallbackResults.isEmpty {
            return fallbackResults
        }
        
        // 4. Return sample or filtered results if all network calls fail
        return filterSampleVideos(for: trimmed)
    }
    
    // Check if query is a YouTube URL
    private func extractDirectVideo(from text: String) -> YouTubeVideo? {
        var videoId: String?
        
        // Match: youtu.be/<id>
        if text.contains("youtu.be/") {
            let parts = text.components(separatedBy: "youtu.be/")
            if parts.count > 1 {
                videoId = parts[1].components(separatedBy: CharacterSet(charactersIn: "?&/#")).first
            }
        }
        // Match: youtube.com/watch?v=<id>
        else if text.contains("youtube.com/watch") {
            if let url = URL(string: text),
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems {
                videoId = queryItems.first(where: { $0.name == "v" })?.value
            }
        }
        // Match 11-char video ID directly (alphanumeric, -, _)
        else if text.count == 11 && text.range(of: "^[a-zA-Z0-9_-]{11}$", options: .regularExpression) != nil {
            videoId = text
        }
        
        guard let id = videoId, !id.isEmpty else { return nil }
        return YouTubeVideo(
            id: id,
            title: "YouTube Video (\(id))",
            channelTitle: "YouTube",
            thumbnailUrlString: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg",
            durationString: "--:--",
            viewCountString: "",
            publishedTimeString: ""
        )
    }
    
    // MARK: - Method 1: YouTube Web Search Scraper
    private func searchViaYouTubeWeb(query: String) async -> [YouTubeVideo]? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.youtube.com/results?search_query=\(encoded)&sp=EgIQAQ%253D%253D") else {
            return nil
        }
        
        do {
            let (data, _) = try await session.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            return parseYouTubeInitialData(from: html)
        } catch {
            print("TubePlay: YouTube web search error: \(error)")
            return nil
        }
    }
    
    private func parseYouTubeInitialData(from html: String) -> [YouTubeVideo] {
        guard let startRange = html.range(of: "var ytInitialData = "),
              let endRange = html.range(of: ";</script>", range: startRange.upperBound..<html.endIndex) else {
            return []
        }
        
        let jsonString = String(html[startRange.upperBound..<endRange.lowerBound])
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return []
        }
        
        var videos: [YouTubeVideo] = []
        
        // Traverse: contents -> twoColumnSearchResultsRenderer -> primaryContents -> sectionListRenderer -> contents
        if let contents = json["contents"] as? [String: Any],
           let twoCol = contents["twoColumnSearchResultsRenderer"] as? [String: Any],
           let primary = twoCol["primaryContents"] as? [String: Any],
           let sectionList = primary["sectionListRenderer"] as? [String: Any],
           let sections = sectionList["contents"] as? [[String: Any]] {
            
            for section in sections {
                if let itemSection = section["itemSectionRenderer"] as? [String: Any],
                   let items = itemSection["contents"] as? [[String: Any]] {
                    for item in items {
                        if let videoRenderer = item["videoRenderer"] as? [String: Any] {
                            if let video = parseVideoRenderer(videoRenderer) {
                                videos.append(video)
                            }
                        }
                    }
                }
            }
        }
        
        return videos
    }
    
    private func parseVideoRenderer(_ dict: [String: Any]) -> YouTubeVideo? {
        guard let videoId = dict["videoId"] as? String else { return nil }
        
        // Title
        var title = ""
        if let titleDict = dict["title"] as? [String: Any],
           let runs = titleDict["runs"] as? [[String: Any]],
           let firstRun = runs.first,
           let text = firstRun["text"] as? String {
            title = text
        }
        
        // Channel
        var channel = ""
        if let ownerText = dict["ownerText"] as? [String: Any],
           let runs = ownerText["runs"] as? [[String: Any]],
           let firstRun = runs.first,
           let text = firstRun["text"] as? String {
            channel = text
        }
        
        // Duration
        var duration = ""
        if let lengthText = dict["lengthText"] as? [String: Any],
           let simpleText = lengthText["simpleText"] as? String {
            duration = simpleText
        }
        
        // View Count
        var viewCount = ""
        if let viewCountText = dict["viewCountText"] as? [String: Any],
           let simpleText = viewCountText["simpleText"] as? String {
            viewCount = simpleText
        }
        
        // Published Time
        var publishedTime = ""
        if let publishedTimeText = dict["publishedTimeText"] as? [String: Any],
           let simpleText = publishedTimeText["simpleText"] as? String {
            publishedTime = simpleText
        }
        
        // Thumbnail
        var thumbUrl = "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"
        if let thumbDict = dict["thumbnail"] as? [String: Any],
           let thumbnails = thumbDict["thumbnails"] as? [[String: Any]],
           let lastThumb = thumbnails.last,
           let urlString = lastThumb["url"] as? String {
            thumbUrl = urlString
        }
        
        return YouTubeVideo(
            id: videoId,
            title: title.isEmpty ? "Video \(videoId)" : title,
            channelTitle: channel.isEmpty ? "YouTube Channel" : channel,
            thumbnailUrlString: thumbUrl,
            durationString: duration,
            viewCountString: viewCount,
            publishedTimeString: publishedTime
        )
    }
    
    // MARK: - Method 2: Invidious Public API Fallback
    private func searchViaInvidious(query: String) async -> [YouTubeVideo]? {
        let instances = [
            "https://inv.tux.pizza",
            "https://invidious.nerdvpn.de",
            "https://vid.puffyan.us",
            "https://invidious.drgns.space"
        ]
        
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        for instance in instances {
            guard let url = URL(string: "\(instance)/api/v1/search?q=\(encoded)&type=video") else { continue }
            do {
                let (data, _) = try await session.data(from: url)
                if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], !array.isEmpty {
                    var videos: [YouTubeVideo] = []
                    for item in array {
                        if let videoId = item["videoId"] as? String,
                           let title = item["title"] as? String,
                           let author = item["author"] as? String {
                            
                            let seconds = item["lengthSeconds"] as? Int ?? 0
                            let duration = formatSeconds(seconds)
                            let views = item["viewCount"] as? Int ?? 0
                            let viewsStr = views > 0 ? "\(views) views" : ""
                            let published = item["publishedText"] as? String ?? ""
                            
                            videos.append(YouTubeVideo(
                                id: videoId,
                                title: title,
                                channelTitle: author,
                                thumbnailUrlString: "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg",
                                durationString: duration,
                                viewCountString: viewsStr,
                                publishedTimeString: published
                            ))
                        }
                    }
                    if !videos.isEmpty { return videos }
                }
            } catch {
                continue
            }
        }
        return nil
    }
    
    private func formatSeconds(_ totalSeconds: Int) -> String {
        guard totalSeconds > 0 else { return "" }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func filterSampleVideos(for query: String) -> [YouTubeVideo] {
        let lower = query.lowercased()
        let filtered = YouTubeVideo.sampleList.filter {
            $0.title.lowercased().contains(lower) || $0.channelTitle.lowercased().contains(lower)
        }
        return filtered.isEmpty ? YouTubeVideo.sampleList : filtered
    }
    
    // Curated Discover categories
    public static let curatedCategories: [(title: String, icon: String, query: String)] = [
        ("Lofi Beats", "music.note", "lofi hip hop radio beats to relax study to"),
        ("Deep Focus", "brain.head.profile", "deep focus study ambient sound music"),
        ("Chill Acoustic", "guitars.fill", "acoustic guitar relaxing chill music"),
        ("Sleep Ambient", "moon.stars.fill", "ambient sleep music delta waves black screen"),
        ("Tech Podcasts", "mic.fill", "technology podcast interview"),
        ("Top Hits", "flame.fill", "billboard hot 100 music playlist")
    ]
}
