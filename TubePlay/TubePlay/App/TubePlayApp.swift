import SwiftUI

@main
struct TubePlayApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark) // Sleek dark theme matching YouTube & music players
        }
    }
}
