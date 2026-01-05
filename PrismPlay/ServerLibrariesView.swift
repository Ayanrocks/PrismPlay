import SwiftUI

struct ServerLibrariesView: View {
    let server: JellyfinServerConfig
    @ObservedObject private var jellyfinService = JellyfinService.shared
    @State private var libraries: [JellyfinLibrary] = []
    @State private var isLoading = false
    
    let columns = [
        GridItem(.adaptive(minimum: 150))
    ]
    
    var body: some View {
        ZStack {
            PrismBackground()
            
            if isLoading {
                ProgressView("Loading libraries...")
                    .foregroundColor(.white)
            } else if libraries.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No libraries found")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(libraries) { library in
                            NavigationLink(destination: FullLibraryView(library: library)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 15)
                                            .fill(Color.white.opacity(0.1))
                                            .frame(height: 120)
                                        
                                        VStack(spacing: 8) {
                                            Image(systemName: libraryIcon(for: library.CollectionType))
                                                .font(.system(size: 40))
                                                .foregroundColor(.purple)
                                            
                                            Text(library.Name)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .multilineTextAlignment(.center)
                                        }
                                        .padding()
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(server.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadLibraries()
        }
    }
    
    func loadLibraries() {
        // Ensure this server is selected
        jellyfinService.selectServer(server)
        
        isLoading = true
        jellyfinService.fetchLibraries { fetchedLibraries in
            Task { @MainActor in
                isLoading = false
                if let fetchedLibraries = fetchedLibraries {
                    self.libraries = fetchedLibraries
                }
            }
        }
    }
    
    func libraryIcon(for collectionType: String?) -> String {
        guard let type = collectionType else { return "folder.fill" }
        
        switch type.lowercased() {
        case "movies":
            return "film.fill"
        case "tvshows":
            return "tv.fill"
        case "music":
            return "music.note"
        case "books":
            return "book.fill"
        case "photos":
            return "photo.fill"
        default:
            return "folder.fill"
        }
    }
}
