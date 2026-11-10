import Foundation
import MediaPlayer
import UIKit

public final class NowPlayingManager {
    public static let shared = NowPlayingManager()
    
    // Command callbacks wired to PlayerEngine
    public var onPlay: (() -> Void)?
    public var onPause: (() -> Void)?
    public var onTogglePlayPause: (() -> Void)?
    public var onSkipForward: ((Double) -> Void)?
    public var onSkipBackward: ((Double) -> Void)?
    public var onSeekTo: ((Double) -> Void)?
    public var onNextTrack: (() -> Void)?
    public var onPreviousTrack: (() -> Void)?
    
    private var cachedArtwork: (url: URL, image: UIImage)?
    
    private init() {
        setupRemoteCommands()
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.onPlay?()
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.onPause?()
            return .success
        }
        
        // Toggle Play / Pause (e.g. EarPods button click)
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.onTogglePlayPause?()
            return .success
        }
        
        // Skip Forward 15s
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            self?.onSkipForward?(skipEvent.interval)
            return .success
        }
        
        // Skip Backward 15s
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            self?.onSkipBackward?(skipEvent.interval)
            return .success
        }
        
        // Scrubbing / Seek bar on Lock Screen
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.onSeekTo?(positionEvent.positionTime)
            return .success
        }
        
        // Next Track
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.onNextTrack?()
            return .success
        }
        
        // Previous Track
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.onPreviousTrack?()
            return .success
        }
    }
    
    /// Updates lock screen and control center with current track info
    public func updateNowPlaying(
        video: YouTubeVideo?,
        isPlaying: Bool,
        currentTime: Double,
        duration: Double
    ) {
        guard let video = video else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        
        info[MPMediaItemPropertyTitle] = video.title
        info[MPMediaItemPropertyArtist] = video.channelTitle
        info[MPMediaItemPropertyAlbumTitle] = "YouTube Background"
        
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // Set info immediately
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        // Asynchronously load and set artwork if needed
        if let thumbUrl = video.thumbnailUrl {
            if let cached = cachedArtwork, cached.url == thumbUrl {
                setArtwork(cached.image)
            } else {
                fetchArtwork(from: thumbUrl)
            }
        }
    }
    
    private func fetchArtwork(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil, let image = UIImage(data: data) else {
                return
            }
            self.cachedArtwork = (url, image)
            DispatchQueue.main.async {
                self.setArtwork(image)
            }
        }.resume()
    }
    
    private func setArtwork(_ image: UIImage) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        info[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    public func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        cachedArtwork = nil
    }
}
