import SwiftUI
import Combine

struct SearchView: View {
    @ObservedObject private var jellyfinService = JellyfinService.shared
    @State private var searchText = ""
    @State private var searchResults: [JellyfinItem] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    
    // Debounce publisher
    @State private var searchTextPublisher = PassthroughSubject<String, Never>()
    @State private var cancellables = Set<AnyCancellable>()
    
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            PrismBackground()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Search")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Search Field
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                    
                    TextField("Search movies and shows...", text: $searchText)
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: searchText) { newValue in
                            searchTextPublisher.send(newValue)
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                            hasSearched = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Content
                if isSearching {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Text("Searching...")
                        .foregroundColor(.gray)
                        .padding(.top, 12)
                    Spacer()
                } else if searchText.isEmpty && !hasSearched {
                    // Empty state - no search yet
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Search for movies and TV shows")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Results will appear as you type")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    Spacer()
                } else if searchResults.isEmpty && hasSearched {
                    // No results
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No results found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    Spacer()
                } else {
                    // Results Grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(searchResults) { item in
                                NavigationLink(destination: MediaDetailsView(item: item)) {
                                    SearchResultCard(item: item, jellyfinService: jellyfinService)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupDebounce()
        }
    }
    
    private func setupDebounce() {
        searchTextPublisher
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { query in
                performSearch(query: query)
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            hasSearched = false
            return
        }
        
        isSearching = true
        hasSearched = true
        
        jellyfinService.searchItems(query: query) { items in
            Task { @MainActor in
                self.searchResults = items ?? []
                self.isSearching = false
            }
        }
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let item: JellyfinItem
    let jellyfinService: JellyfinService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster Image
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: jellyfinService.imageURL(for: item.Id, imageTag: item.primaryImageTag)) { image in
                    image
                        .resizable()
                        .aspectRatio(2/3, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(2/3, contentMode: .fill)
                        .overlay(
                            Image(systemName: item.ItemType == "Series" ? "tv" : "film")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        )
                }
                .frame(height: 180)
                .cornerRadius(8)
                .clipped()
                
                // Type Badge
                HStack(spacing: 4) {
                    Image(systemName: item.ItemType == "Series" ? "tv" : "film")
                        .font(.system(size: 10))
                    Text(item.ItemType == "Series" ? "TV" : "Movie")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
                .foregroundColor(.white)
                .padding(6)
            }
            
            // Title
            Text(item.Name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Year
            if let year = item.ProductionYear {
                Text(String(year))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
