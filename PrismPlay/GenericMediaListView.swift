import SwiftUI

struct GenericMediaListView: View {
    let title: String
    let items: [JellyfinItem]
    let isLoading: Bool
    @ObservedObject var jellyfinService = JellyfinService.shared
    
    let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            // Background
            // Background
            PrismBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 50)
                    } else if items.isEmpty {
                        Text("No items found.")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 50)
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(items) { item in
                                NavigationLink(destination: MediaDetailsView(item: item)) {
                                    VStack(alignment: .leading, spacing: 8) {
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
                                        .frame(height: 160)
                                        .cornerRadius(10)
                                        .clipped()
                                        
                                        Text(item.Name)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .lineLimit(nil)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
