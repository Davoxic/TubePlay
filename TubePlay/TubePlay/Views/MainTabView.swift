import SwiftUI

public struct MainTabView: View {
    @ObservedObject var playerEngine = YouTubePlayerEngine.shared
    @State private var selectedTab: Int = 0
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(0)
                
                BrowserView()
                    .tabItem {
                        Label("Browser", systemImage: "globe")
                    }
                    .tag(1)
                
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "music.note.list")
                    }
                    .tag(2)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(3)
            }
            .tint(.red)
            
            // Persistent Mini-Player floating above TabBar
            if playerEngine.isMiniPlayerVisible && playerEngine.currentVideo != nil {
                MiniPlayerView()
                    .padding(.bottom, 54) // Align right above standard iOS tab bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $playerEngine.isFullPlayerPresented) {
            FullPlayerView()
        }
    }
}
