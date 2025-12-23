import SwiftUI

enum LibrarySortOption: String, CaseIterable, Identifiable {
    case dateAdded = "DateCreated"
    case name = "SortName"
    case rating = "CommunityRating"
    case releaseDate = "PremiereDate"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .dateAdded: return "Date Added"
        case .name: return "Name"
        case .rating: return "Rating"
        case .releaseDate: return "Release Date"
        }
    }
}

enum SortOrder: String {
    case ascending = "Ascending"
    case descending = "Descending"
}

struct FullLibraryView: View {
    let library: JellyfinLibrary
    @ObservedObject private var jellyfinService = JellyfinService.shared
    
    @State private var items: [JellyfinItem] = []
    @State private var isLoading = false
    @State private var currentPage = 0
    @State private var hasMoreItems = true
    @State private var showSortOptions = false
    @State private var selectedSort: LibrarySortOption = .dateAdded
    @State private var sortOrder: SortOrder = .descending
    
    let itemsPerPage = 30
    let columns = [
        GridItem(.adaptive(minimum: 150))
    ]
    
    var body: some View {
        ZStack {
            PrismBackground()
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(items) { item in
                        NavigationLink(destination: MediaDetailsView(item: item)) {
                            VStack {
                                AsyncImage(url: jellyfinService.imageURL(for: item.Id, imageTag: item.primaryImageTag)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "film")
                                                .foregroundColor(.white)
                                        )
                                }
                                .frame(height: 220)
                                .cornerRadius(10)
                                .clipped()
                                
                                Text(item.Name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .buttonStyle(PlainButtonStyle()) // Keeps the original look without blue link styling
                        .onAppear {
                            // Load more when approaching end
                            if item.id == items.last?.id && !isLoading && hasMoreItems {
                                loadMoreItems()
                            }
                        }
                    }
                    
                    // Loading indicator at bottom
                    if isLoading {
                        ProgressView()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .gridCellColumns(columns.count)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(library.Name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showSortOptions = true
                }) {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.white)
                }
            }
        }
        .confirmationDialog("Sort By", isPresented: $showSortOptions, titleVisibility: .visible) {
            ForEach(LibrarySortOption.allCases) { option in
                Button(option.displayName) {
                    selectedSort = option
                    resetAndReload()
                }
            }
            
            Button("Order: \(sortOrder == .ascending ? "Ascending" : "Descending")") {
                sortOrder = sortOrder == .ascending ? .descending : .ascending
                resetAndReload()
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            if items.isEmpty {
                loadInitialItems()
            }
        }
    }
    
    func loadInitialItems() {
        isLoading = true
        currentPage = 0
        items = []
        
        jellyfinService.fetchLibraryItemsPaginated(
            libraryId: library.Id,
            startIndex: 0,
            limit: itemsPerPage,
            sortBy: selectedSort.rawValue,
            sortOrder: sortOrder.rawValue
        ) { fetchedItems in
            Task { @MainActor in
                isLoading = false
                if let fetchedItems = fetchedItems {
                    items = fetchedItems
                    hasMoreItems = fetchedItems.count >= itemsPerPage
                    currentPage = 1
                }
            }
        }
    }
    
    func loadMoreItems() {
        guard !isLoading && hasMoreItems else { return }
        
        isLoading = true
        let startIndex = currentPage * itemsPerPage
        
        jellyfinService.fetchLibraryItemsPaginated(
            libraryId: library.Id,
            startIndex: startIndex,
            limit: itemsPerPage,
            sortBy: selectedSort.rawValue,
            sortOrder: sortOrder.rawValue
        ) { fetchedItems in
            Task { @MainActor in
                isLoading = false
                if let fetchedItems = fetchedItems {
                    items.append(contentsOf: fetchedItems)
                    hasMoreItems = fetchedItems.count >= itemsPerPage
                    currentPage += 1
                }
            }
        }
    }
    
    func resetAndReload() {
        items = []
        currentPage = 0
        hasMoreItems = true
        loadInitialItems()
    }
}
