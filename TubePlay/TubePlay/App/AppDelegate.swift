import UIKit
import AVFoundation

public class AppDelegate: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Activate background audio session immediately on launch
        _ = AudioSessionManager.shared.configureAudioSession()
        
        // Begin receiving remote control events (lock screen / control center / airpods)
        application.beginReceivingRemoteControlEvents()
        
        print("TubePlay: AppDelegate launched and configured audio session.")
        return true
    }
}
