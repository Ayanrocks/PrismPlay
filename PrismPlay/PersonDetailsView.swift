import SwiftUI

struct PersonDetailsView: View {
    let personName: String
    let personId: String
    let personImageTag: String?
    
    @State private var movies: [JellyfinItem] = []
    @State private var isLoading = true
    @ObservedObject var jellyfinService = JellyfinService.shared
    
    var body: some View {
        ZStack {
            GenericMediaListView(title: personName, items: movies, isLoading: isLoading)
        }
        .onAppear {
            loadMovies()
        }
    }
    
    private func loadMovies() {
        jellyfinService.fetchItems(byPersonId: personId) { items in
            Task { @MainActor in
                if let items = items {
                    self.movies = items
                }
                self.isLoading = false
            }
        }
    }
}
