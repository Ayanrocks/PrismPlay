import SwiftUI

struct MediaLibraryView: View {
    @StateObject private var jellyfinService = JellyfinService.shared
    @State private var items: [JellyfinItem] = []
    @State private var isLoading = true
    
    let columns = [
        GridItem(.adaptive(minimum: 150))
    ]
    
    var body: some View {
        ZStack {
            PrismBackground()
            
            if isLoading {
                ProgressView("Loading Library...")
                    .foregroundColor(.white)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(items) { item in
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
                                    .lineLimit(nil)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadContent()
        }
    }
    
    func loadContent() {
        jellyfinService.fetchMediaItems { fetchedItems in
            Task { @MainActor in
                isLoading = false
                if let fetchedItems = fetchedItems {
                    self.items = fetchedItems
                }
            }
        }
    }
}

#Preview {
    MediaLibraryView()
}
