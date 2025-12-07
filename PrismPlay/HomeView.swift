import SwiftUI

struct LibraryWithItems: Identifiable {
    let library: JellyfinLibrary
    var items: [JellyfinItem]
    
    var id: String { library.Id }
}

struct HomeView: View {
    @ObservedObject private var jellyfinService = JellyfinService.shared
    @State private var showJellyfinLogin = false
    @State private var librariesWithItems: [LibraryWithItems] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.4), Color.blue.opacity(0.4)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .edgesIgnoringSafeArea(.all)
                
                if jellyfinService.savedServers.isEmpty {
                    // No server configured
                    VStack(spacing: 40) {
                        Text("PrismPlay")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(radius: 10)
                            .padding(.top, 50)
                        
                        Spacer()
                        
                        GlassmorphicCard {
                            VStack(spacing: 20) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white)
                                
                                Text("No Server Configured")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Button(action: {
                                    showJellyfinLogin = true
                                }) {
                                    Text("Add Jellyfin Server")
                                        .font(.headline)
                                        .foregroundColor(.purple)
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(10)
                                }
                            }
                            .padding(40)
                        }
                        .frame(maxWidth: 350)
                        
                        Spacer()
                    }
                } else {
                    // Server configured - show libraries
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header
                            HStack {
                                Text("PrismPlay")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if let server = jellyfinService.savedServers.first {
                                    Text(server.name)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding()
                            .padding(.top, 10)
                            
                            if isLoading {
                                ProgressView("Loading libraries...")
                                    .foregroundColor(.white)
                                    .padding()
                            } else if librariesWithItems.isEmpty {
                                Text("No libraries found")
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding()
                            } else {
                                ForEach(librariesWithItems) { libraryWithItems in
                                    LibraryRowView(
                                        library: libraryWithItems.library,
                                        items: libraryWithItems.items,
                                        jellyfinService: jellyfinService,
                                        onSeeMore: {
                                            // Navigate to full library view
                                            // TODO: Implement navigation to full library
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showJellyfinLogin) {
                JellyfinLoginView(isPresented: $showJellyfinLogin)
            }
            .onAppear {
                loadLibraries()
            }
        }
    }
    
    func loadLibraries() {
        guard !jellyfinService.savedServers.isEmpty else { return }
        
        // Auto-select first server if not authenticated
        if !jellyfinService.isAuthenticated, let firstServer = jellyfinService.savedServers.first {
            jellyfinService.selectServer(firstServer)
        }
        
        isLoading = true
        librariesWithItems = []
        
        jellyfinService.fetchLibraries { libraries in
            Task { @MainActor in
                guard let libraries = libraries else {
                    isLoading = false
                    return
                }
                
                let group = DispatchGroup()
                var tempLibrariesWithItems: [LibraryWithItems] = []
                
                for library in libraries {
                    group.enter()
                    jellyfinService.fetchLibraryItems(libraryId: library.Id, limit: 10) { items in
                        if let items = items {
                            tempLibrariesWithItems.append(LibraryWithItems(library: library, items: items))
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    Task { @MainActor in
                        self.librariesWithItems = tempLibrariesWithItems
                        self.isLoading = false
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
