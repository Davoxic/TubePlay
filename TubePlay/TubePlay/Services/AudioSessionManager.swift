import Foundation
import AVFoundation

public final class AudioSessionManager {
    public static let shared = AudioSessionManager()
    
    public var onInterruptionBegan: (() -> Void)?
    public var onInterruptionEnded: ((Bool) -> Void)?
    public var onHeadphonesUnplugged: (() -> Void)?
    
    private init() {
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Configures and activates the AVAudioSession for seamless background playback
    @discardableResult
    public func configureAudioSession() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            
            // Setting category to .playback tells iOS this app plays audio that should continue
            // when the screen locks or when the silent switch is on.
            try session.setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
            )
            
            try session.setActive(true, options: [])
            print("TubePlay: AVAudioSession activated successfully.")
            return true
        } catch {
            print("TubePlay: Failed to configure AVAudioSession: \(error.localizedDescription)")
            return false
        }
    }
    
    public func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("TubePlay: Failed to deactivate AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    private func setupNotifications() {
        let center = NotificationCenter.default
        
        // Handle phone calls, alarms, Siri interruptions
        center.addObserver(
            self,
            selector: #selector(handleInterruption(notification:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        // Handle headphones plugged / unplugged
        center.addObserver(
            self,
            selector: #selector(handleRouteChange(notification:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("TubePlay: Audio interruption began")
            onInterruptionBegan?()
            
        case .ended:
            print("TubePlay: Audio interruption ended")
            var shouldResume = false
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                shouldResume = options.contains(.shouldResume)
            }
            // Reactivate session
            _ = configureAudioSession()
            onInterruptionEnded?(shouldResume)
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Headphones unplugged, pause to avoid blasting speakers in public
            print("TubePlay: Output device unavailable (headphones unplugged)")
            onHeadphonesUnplugged?()
        default:
            break
        }
    }
}
