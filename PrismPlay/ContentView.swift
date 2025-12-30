import SwiftUI

enum AppTab: Int, Hashable {
    case home
    case search
    case localFiles
    case servers
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var homeNavigationPath = NavigationPath()
    @State private var searchNavigationPath = NavigationPath()
    @State private var localFilesNavigationPath = NavigationPath()
    @State private var serversNavigationPath = NavigationPath()
    
    init() {
        // Customize Tab Bar appearance to match the premium feel
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: tabSelection) {
            NavigationStack(path: $homeNavigationPath) {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.home)
            
            NavigationStack(path: $searchNavigationPath) {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(AppTab.search)
            
            NavigationStack(path: $localFilesNavigationPath) {
                LocalFilesView()
            }
            .tabItem {
                Label("Local Files", systemImage: "folder.fill")
            }
            .tag(AppTab.localFiles)
            
            NavigationStack(path: $serversNavigationPath) {
                ServerManagementView()
            }
            .tabItem {
                Label("Servers", systemImage: "server.rack")
            }
            .tag(AppTab.servers)
        }
        .accentColor(.purple)
        .preferredColorScheme(.dark)
    }
    
    /// Custom binding that resets navigation when the same tab is tapped
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == selectedTab {
                    // Same tab tapped - reset navigation to root
                    switch newTab {
                    case .home:
                        homeNavigationPath = NavigationPath()
                    case .search:
                        searchNavigationPath = NavigationPath()
                    case .localFiles:
                        localFilesNavigationPath = NavigationPath()
                    case .servers:
                        serversNavigationPath = NavigationPath()
                    }
                }
                selectedTab = newTab
            }
        )
    }
}

#Preview {
    ContentView()
}
