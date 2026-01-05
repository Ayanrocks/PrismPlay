import SwiftUI

struct LibraryRowView: View {
    let library: JellyfinLibrary
    let items: [JellyfinItem]
    let serverConfig: JellyfinServerConfig  // NEW
    let jellyfinService: JellyfinService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("\(library.Name) - \(serverConfig.name)")  // UPDATED with server identifier
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                NavigationLink(destination: FullLibraryView(library: library)) {
                    HStack(spacing: 4) {
                        Text("See More")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(items) { item in
                        NavigationLink(destination: MediaDetailsView(item: item)) {
                            VStack(alignment: .leading, spacing: 8) {
                                AsyncImage(url: jellyfinService.imageURL(for: item.Id, imageTag: item.primaryImageTag, server: serverConfig)) { image in
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
                                    .lineLimit(2)
                                    .frame(width: 120, height: 36, alignment: .topLeading)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 10)
    }
}
