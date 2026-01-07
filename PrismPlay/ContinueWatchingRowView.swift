import SwiftUI

/// A horizontal scrolling row for "Continue Watching" items
struct ContinueWatchingRowView: View {
    let items: [ResumeItemWithServer]
    @ObservedObject var jellyfinService = JellyfinService.shared
    @Binding var selectedItem: ResumeItemWithServer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Continue Watching")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(items) { resumeItem in
                        Button(action: {
                            selectedItem = resumeItem
                        }) {
                            ContinueWatchingCard(item: resumeItem.item, server: resumeItem.server, jellyfinService: jellyfinService)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 10)
    }
}

/// Individual card for a continue watching item
struct ContinueWatchingCard: View {
    let item: JellyfinItem
    let server: JellyfinServerConfig
    let jellyfinService: JellyfinService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                // Thumbnail with wider aspect ratio for continue watching
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
                .frame(width: 160, height: 90)
                .cornerRadius(8)
                .clipped()
                .playbackProgressOverlay(for: item, showRemainingTime: false)
                
                // Play button overlay in center
                PlayButtonOverlay(item: item, size: 44)
            }
            
            // Title and info
            VStack(alignment: .leading, spacing: 2) {
                if let seriesName = item.SeriesName {
                    Text(seriesName)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Text(displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Show server name for multi-server context
                Text(server.name)
                    .font(.caption2)
                    .foregroundColor(.purple.opacity(0.8))
                    .lineLimit(1)
                
                if let remaining = item.remainingTimeString {
                    Text(remaining)
                        .font(.caption2)
                        .foregroundColor(.purple)
                }
            }
            .frame(width: 160, alignment: .leading)
        }
    }
    
    private var displayTitle: String {
        if item.ItemType == "Episode" {
            if let seasonNum = item.ParentIndexNumber, let epNum = item.IndexNumber {
                return "S\(seasonNum):E\(epNum) \(item.Name)"
            }
        }
        return item.Name
    }
}
