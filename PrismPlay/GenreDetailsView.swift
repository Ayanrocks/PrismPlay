import SwiftUI

struct GenreDetailsView: View {
    let genre: String
    
    @State private var movies: [JellyfinItem] = []
    @State private var isLoading = true
    @ObservedObject var jellyfinService = JellyfinService.shared
    
    var body: some View {
        GenericMediaListView(title: genre, items: movies, isLoading: isLoading)
        .onAppear {
            loadMovies()
        }
    }
    
    private func loadMovies() {
        jellyfinService.fetchItems(byGenre: genre) { items in
            Task { @MainActor in
                if let items = items {
                    self.movies = items
                }
                self.isLoading = false
            }
        }
    }
}
