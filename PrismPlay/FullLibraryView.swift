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
    let server: JellyfinServerConfig
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
    
    @State private var totalItems: Int? = nil
    
    // Threshold for pre-fetching (load more when user sees this many items from end)
    let prefetchThreshold = 5
    
    var body: some View {
        ZStack {
            PrismBackground()
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        NavigationLink(destination: MediaDetailsView(item: item, server: server)) {
                            VStack {
                                AsyncImage(url: jellyfinService.imageURL(for: item.Id, imageTag: item.primaryImageTag, server: server)) { image in
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
                        .buttonStyle(PlainButtonStyle())
                        .onAppear {
                            // Prefetch when reaching the threshold
                            if index >= items.count - prefetchThreshold && !isLoading && hasMoreItems {
                                loadMoreItems()
                            }
                        }
                    }
                    
                    // Loading indicator
                    if isLoading || hasMoreItems {
                        // Keep space for loading indicator or bottom spacing
                        ProgressView()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .gridCellColumns(columns.count)
                            .onAppear {
                                // Fallback: if user scrolled to bottom and trigger didn't fire
                                if !isLoading && hasMoreItems {
                                    loadMoreItems()
                                }
                            }
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
            // Ensure this server is selected for all downstream views (MediaDetailsView, etc.)
            jellyfinService.selectServer(server)
            
            if items.isEmpty {
                loadInitialItems()
            }
        }
    }
    
    func loadInitialItems() {
        isLoading = true
        currentPage = 0
        items = []
        totalItems = nil
        hasMoreItems = true
        
        jellyfinService.fetchLibraryItemsPaginated(
            libraryId: library.Id,
            for: server,
            startIndex: 0,
            limit: itemsPerPage,
            sortBy: selectedSort.rawValue,
            sortOrder: sortOrder.rawValue
        ) { (fetchedItems, total) in
            Task { @MainActor in
                isLoading = false
                if let fetchedItems = fetchedItems {
                    self.items = fetchedItems
                    self.totalItems = total
                    
                    // Update pagination state
                    self.currentPage = 1
                    
                    // Check if we have more based on total count
                    if let total = total {
                        self.hasMoreItems = self.items.count < total
                    } else {
                        // Fallback logic if total is missing
                        self.hasMoreItems = fetchedItems.count >= self.itemsPerPage
                    }
                }
            }
        }
    }
    
    func loadMoreItems() {
        guard !isLoading && hasMoreItems else { return }
        
        // Double check if we've reached the total
        if let total = totalItems, items.count >= total {
            hasMoreItems = false
            return
        }
        
        isLoading = true
        let startIndex = currentPage * itemsPerPage
        
        jellyfinService.fetchLibraryItemsPaginated(
            libraryId: library.Id,
            for: server,
            startIndex: startIndex,
            limit: itemsPerPage,
            sortBy: selectedSort.rawValue,
            sortOrder: sortOrder.rawValue
        ) { (fetchedItems, total) in
            Task { @MainActor in
                isLoading = false
                
                if let fetchedItems = fetchedItems {
                    // Update total if it changed (unlikely but possible)
                    if let total = total {
                        self.totalItems = total
                    }
                    
                    // Append new unique items
                    let newItems = fetchedItems.filter { newItem in
                        !self.items.contains(where: { $0.Id == newItem.Id })
                    }
                    
                    if !newItems.isEmpty {
                        self.items.append(contentsOf: newItems)
                        self.currentPage += 1
                    } else {
                        // If we got no new items, maybe we reached the end or they were all duplicates/invalid
                        // But we should increment page to try next batch if we believe there are more
                        // However, if filtering removed them, we might need to fetch MORE immediately?
                        // For simplicity, just increment page.
                        self.currentPage += 1
                    }
                    
                    // Update hasMore
                    if let total = self.totalItems {
                         // Stop if we have loaded all items Or if the start index is past the total
                         self.hasMoreItems = self.items.count < total && (startIndex < total)
                    } else {
                         self.hasMoreItems = !fetchedItems.isEmpty
                    }
                } else {
                    // Error case
                    // Don't disable hasMoreItems, user can try scrolling again (retry)
                }
            }
        }
    }
    
    func resetAndReload() {
        items = []
        currentPage = 0
        hasMoreItems = true
        totalItems = nil
        loadInitialItems()
    }
}
