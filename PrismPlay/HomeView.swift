import SwiftUI

struct LibraryWithItems: Identifiable {
    let library: JellyfinLibrary
    var items: [JellyfinItem]
    let serverConfig: JellyfinServerConfig
    
    var id: String { "\(serverConfig.id.uuidString)-\(library.Id)" }
}

struct HomeView: View {
    @ObservedObject private var jellyfinService = JellyfinService.shared
    @State private var showJellyfinLogin = false
    @State private var librariesWithItems: [LibraryWithItems] = []
    @State private var resumeItems: [ResumeItemWithServer] = []
    @State private var isLoading = false
    @State private var playingResumeItem: ResumeItemWithServer?
    @State private var hasLoadedOnce = false
    
    var body: some View {
        ZStack {
            // Background
            PrismBackground()
            
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
                        // Header with refresh button
                        HStack {
                            Text("PrismPlay")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // Manual refresh button
                            Button(action: {
                                loadLibraries()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(isLoading ? 0.5 : 1.0))
                            }
                            .disabled(isLoading)
                            .padding(.trailing, 8)
                            
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
                            // Continue Watching Section (if any)
                            if !resumeItems.isEmpty {
                                ContinueWatchingRowView(items: resumeItems, jellyfinService: jellyfinService, selectedItem: $playingResumeItem)
                            }
                            
                            // Library Rows
                            ForEach(librariesWithItems) { libraryWithItems in
                                LibraryRowView(
                                    library: libraryWithItems.library,
                                    items: libraryWithItems.items,
                                    serverConfig: libraryWithItems.serverConfig,
                                    jellyfinService: jellyfinService
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
        .fullScreenCover(item: $playingResumeItem) { resumeItem in
            JellyfinPlayerView(item: resumeItem.item, server: resumeItem.server)
        }
        .onAppear {
            // Only load on first appearance to prevent re-fetching on navigation return
            if !hasLoadedOnce {
                loadLibraries()
                hasLoadedOnce = true
            }
        }
    }
    
    func loadLibraries() {
        guard !jellyfinService.savedServers.isEmpty else { return }
        
        isLoading = true
        librariesWithItems = []
        resumeItems = []
        
        Task {
            var allLibrariesWithItems: [LibraryWithItems] = []
            var allResumeItems: [ResumeItemWithServer] = []
            
            // Fetch from ALL servers
            for server in jellyfinService.savedServers {
                // Fetch resume items for this server
                if let items = await fetchResumeItemsAsync(for: server) {
                    // Wrap each item with its server context
                    let wrappedItems = items.map { ResumeItemWithServer(item: $0, server: server) }
                    allResumeItems.append(contentsOf: wrappedItems)
                }
                
                // Fetch libraries for this server
                guard let libraries = await fetchLibrariesAsync(for: server) else {
                    continue
                }
                
                // Fetch items for each library in parallel
                await withTaskGroup(of: LibraryWithItems?.self) { group in
                    for library in libraries {
                        group.addTask {
                            if let items = await self.fetchLibraryItemsAsync(libraryId: library.Id, for: server, limit: 10) {
                                return LibraryWithItems(library: library, items: items, serverConfig: server)
                            }
                            return nil
                        }
                    }
                    
                    for await result in group {
                        if let libItem = result {
                            allLibrariesWithItems.append(libItem)
                        }
                    }
                }
            }
            
            // Sort libraries on Main Actor
            await MainActor.run {
                // Sort libraries: Movies first, then TV Shows, then others
                let sortedLibraries = allLibrariesWithItems.sorted { lib1, lib2 in
                    let type1 = lib1.library.CollectionType?.lowercased() ?? ""
                    let type2 = lib2.library.CollectionType?.lowercased() ?? ""
                    
                    if type1 == "movies" && type2 != "movies" {
                        return true
                    } else if type1 != "movies" && type2 == "movies" {
                        return false
                    } else if type1 == "tvshows" && type2 != "tvshows" && type2 != "movies" {
                        return true
                    } else if type1 != "tvshows" && type1 != "movies" && type2 == "tvshows" {
                        return false
                    }
                    // If same type, sort by server name then library name
                    if type1 == type2 {
                        if lib1.serverConfig.name != lib2.serverConfig.name {
                            return lib1.serverConfig.name < lib2.serverConfig.name
                        }
                    }
                    return lib1.library.Name < lib2.library.Name
                }
                
                self.librariesWithItems = sortedLibraries
                self.resumeItems = allResumeItems
                self.isLoading = false
            }
        }
    }
    
    // Helper async wrappers for multi-server support
    private func fetchLibrariesAsync(for server: JellyfinServerConfig) async -> [JellyfinLibrary]? {
        await withCheckedContinuation { continuation in
            jellyfinService.fetchLibraries(for: server) { libraries in
                continuation.resume(returning: libraries)
            }
        }
    }
    
    private func fetchLibraryItemsAsync(libraryId: String, for server: JellyfinServerConfig, limit: Int) async -> [JellyfinItem]? {
        await withCheckedContinuation { continuation in
            jellyfinService.fetchLibraryItems(libraryId: libraryId, for: server, limit: limit) { items in
                continuation.resume(returning: items)
            }
        }
    }
    
    private func fetchResumeItemsAsync(for server: JellyfinServerConfig) async -> [JellyfinItem]? {
        await withCheckedContinuation { continuation in
            jellyfinService.fetchResumeItems(for: server) { items in
                continuation.resume(returning: items)
            }
        }
    }
}

#Preview {
    HomeView()
}
