import SwiftUI

struct LibraryRowView: View {
    let library: JellyfinLibrary
    let items: [JellyfinItem]
    let jellyfinService: JellyfinService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(library.Name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
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
                                .frame(width: 120, height: 180)
                                .cornerRadius(10)
                                .clipped()
                                .playbackProgressOverlay(for: item)
                                
                                Text(item.Name)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .lineLimit(nil)
                                    .frame(width: 120)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                    
                    // See More button with NavigationLink
                    NavigationLink(destination: FullLibraryView(library: library)) {
                        VStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("See More")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(width: 120, height: 180)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 10)
    }
}
