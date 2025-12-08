import SwiftUI

/// A view modifier that adds a playback progress overlay to thumbnails
/// Shows a progress bar at the bottom and optionally a "X min left" badge
struct PlaybackProgressOverlay: ViewModifier {
    let item: JellyfinItem
    let showRemainingTime: Bool
    
    init(item: JellyfinItem, showRemainingTime: Bool = true) {
        self.item = item
        self.showRemainingTime = showRemainingTime
    }
    
    func body(content: Content) -> some View {
        content.overlay(
            VStack {
                Spacer()
                
                // Progress bar at bottom
                if item.isPartiallyWatched {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            Rectangle()
                                .fill(Color.black.opacity(0.5))
                                .frame(height: 4)
                            
                            // Progress fill
                            Rectangle()
                                .fill(Color.purple)
                                .frame(width: geometry.size.width * item.playedProgress, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
        )
        .overlay(
            // Remaining time badge
            Group {
                if showRemainingTime, let remaining = item.remainingTimeString {
                    VStack {
                        HStack {
                            Spacer()
                            Text(remaining)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.75))
                                .cornerRadius(4)
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }
        )
    }
}

extension View {
    /// Adds a playback progress overlay to the view
    func playbackProgressOverlay(for item: JellyfinItem, showRemainingTime: Bool = true) -> some View {
        self.modifier(PlaybackProgressOverlay(item: item, showRemainingTime: showRemainingTime))
    }
}

/// A play button overlay that shows resume state
struct PlayButtonOverlay: View {
    let item: JellyfinItem
    let size: CGFloat
    
    init(item: JellyfinItem, size: CGFloat = 40) {
        self.item = item
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: size, height: size)
            
            // Play icon with optional progress ring
            if item.isPartiallyWatched {
                // Show progress ring around play button
                Circle()
                    .trim(from: 0, to: item.playedProgress)
                    .stroke(Color.purple, lineWidth: 3)
                    .rotationEffect(.degrees(-90))
                    .frame(width: size - 4, height: size - 4)
            }
            
            Image(systemName: item.isPartiallyWatched ? "play.fill" : "play.fill")
                .font(.system(size: size * 0.4))
                .foregroundColor(.white)
        }
    }
}
