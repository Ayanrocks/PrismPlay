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
    @State private var resumeItems: [JellyfinItem] = []
    @State private var isLoading = false
    @State private var playingItem: JellyfinItem?
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
                                ContinueWatchingRowView(items: resumeItems, jellyfinService: jellyfinService, selectedItem: $playingItem)
                            }
                            
                            // Library Rows
                            ForEach(librariesWithItems) { libraryWithItems in
                                LibraryRowView(
                                    library: libraryWithItems.library,
                                    items: libraryWithItems.items,
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
        .fullScreenCover(item: $playingItem) { item in
            JellyfinPlayerView(item: item)
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
        
        // Auto-select first server if not authenticated
        if !jellyfinService.isAuthenticated, let firstServer = jellyfinService.savedServers.first {
            jellyfinService.selectServer(firstServer)
        }
        
        isLoading = true
        librariesWithItems = []
        resumeItems = []
        
        // Fetch resume items first
        jellyfinService.fetchResumeItems { items in
            Task { @MainActor in
                self.resumeItems = items ?? []
            }
        }
        
        Task {
            // First fetch libraries
            guard let libraries = await fetchLibrariesAsync() else {
                await MainActor.run { isLoading = false }
                return
            }
            
            // Then fetch items for each library in parallel
            var newLibrariesWithItems: [LibraryWithItems] = []
            
            await withTaskGroup(of: LibraryWithItems?.self) { group in
                for library in libraries {
                    group.addTask {
                        if let items = await fetchLibraryItemsAsync(libraryId: library.Id, limit: 10) {
                            return LibraryWithItems(library: library, items: items)
                        }
                        return nil
                    }
                }
                
                for await result in group {
                    if let libItem = result {
                        newLibrariesWithItems.append(libItem)
                    }
                }
            }
            
            // Sort libraries on Main Actor
            await MainActor.run {
                // Sort libraries: Movies first, then TV Shows, then others
                let sortedLibraries = newLibrariesWithItems.sorted { lib1, lib2 in
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
                    return lib1.library.Name < lib2.library.Name
                }
                
                self.librariesWithItems = sortedLibraries
                self.isLoading = false
            }
        }
    }
    
    // Helper async wrappers (since JellyfinService uses callbacks)
    // Ideally JellyfinService should expose async methods, but we can wrap them here or update JellyfinService later.
    private func fetchLibrariesAsync() async -> [JellyfinLibrary]? {
        await withCheckedContinuation { continuation in
            jellyfinService.fetchLibraries { libraries in
                continuation.resume(returning: libraries)
            }
        }
    }
    
    private func fetchLibraryItemsAsync(libraryId: String, limit: Int) async -> [JellyfinItem]? {
        await withCheckedContinuation { continuation in
            jellyfinService.fetchLibraryItems(libraryId: libraryId, limit: limit) { items in
                continuation.resume(returning: items)
            }
        }
    }
}

#Preview {
    HomeView()
}
