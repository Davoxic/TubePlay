import Foundation

public struct YouTubeVideo: Identifiable, Codable, Hashable, Equatable {
    public let id: String
    public let title: String
    public let channelTitle: String
    public let thumbnailUrlString: String
    public let durationString: String
    public let viewCountString: String
    public let publishedTimeString: String
    
    public init(
        id: String,
        title: String,
        channelTitle: String,
        thumbnailUrlString: String = "",
        durationString: String = "",
        viewCountString: String = "",
        publishedTimeString: String = ""
    ) {
        self.id = id
        self.title = title
        self.channelTitle = channelTitle
        self.thumbnailUrlString = thumbnailUrlString.isEmpty ? "https://i.ytimg.com/vi/\(id)/hqdefault.jpg" : thumbnailUrlString
        self.durationString = durationString
        self.viewCountString = viewCountString
        self.publishedTimeString = publishedTimeString
    }
    
    public var thumbnailUrl: URL? {
        URL(string: thumbnailUrlString)
    }
    
    public var highResThumbnailUrl: URL? {
        URL(string: "https://i.ytimg.com/vi/\(id)/maxresdefault.jpg") ?? thumbnailUrl
    }
    
    public var watchUrl: URL {
        URL(string: "https://www.youtube.com/watch?v=\(id)")!
    }
    
    public var embedUrl: URL {
        URL(string: "https://www.youtube.com/embed/\(id)?playsinline=1&enablejsapi=1&autoplay=1&controls=1&rel=0")!
    }
    
    // Quick sample video for previews and testing
    public static let sample = YouTubeVideo(
        id: "jfKfPfyJRdk",
        title: "lofi hip hop radio 📚 - beats to relax/study to",
        channelTitle: "Lofi Girl",
        thumbnailUrlString: "https://i.ytimg.com/vi/jfKfPfyJRdk/hqdefault.jpg",
        durationString: "LIVE",
        viewCountString: "55K watching",
        publishedTimeString: "Started streaming"
    )
    
    public static let sampleList: [YouTubeVideo] = [
        YouTubeVideo(
            id: "jfKfPfyJRdk",
            title: "lofi hip hop radio 📚 - beats to relax/study to",
            channelTitle: "Lofi Girl",
            thumbnailUrlString: "https://i.ytimg.com/vi/jfKfPfyJRdk/hqdefault.jpg",
            durationString: "LIVE",
            viewCountString: "55K watching",
            publishedTimeString: "Streaming now"
        ),
        YouTubeVideo(
            id: "5qap5aO4i9A",
            title: "Lofi Hip Hop Radio 💤 - beats to sleep/chill to",
            channelTitle: "Lofi Girl",
            thumbnailUrlString: "https://i.ytimg.com/vi/5qap5aO4i9A/hqdefault.jpg",
            durationString: "LIVE",
            viewCountString: "28K watching",
            publishedTimeString: "Streaming now"
        ),
        YouTubeVideo(
            id: "TURbeWK2wwg",
            title: "Deep Focus ⚡ Ambient Study Music To Concentrate",
            channelTitle: "Quiet Quest - Study Music",
            thumbnailUrlString: "https://i.ytimg.com/vi/TURbeWK2wwg/hqdefault.jpg",
            durationString: "3:04:12",
            viewCountString: "14M views",
            publishedTimeString: "2 years ago"
        ),
        YouTubeVideo(
            id: "kJQP7kiw5Fk",
            title: "Luis Fonsi - Despacito ft. Daddy Yankee",
            channelTitle: "Luis Fonsi",
            thumbnailUrlString: "https://i.ytimg.com/vi/kJQP7kiw5Fk/hqdefault.jpg",
            durationString: "4:42",
            viewCountString: "8.4B views",
            publishedTimeString: "7 years ago"
        )
    ]
}
