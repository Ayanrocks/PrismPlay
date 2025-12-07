import SwiftUI

struct ContentView: View {
    
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
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            LocalFilesView()
                .tabItem {
                    Label("Local Files", systemImage: "folder.fill")
                }
            
            ServerManagementView()
                .tabItem {
                    Label("Servers", systemImage: "server.rack")
                }
        }
        .accentColor(.purple)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
