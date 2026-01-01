import SwiftUI
import AVKit

// MARK: - Glassmorphic Player Button

/// A unified glassmorphic button for video player controls
struct GlassmorphicPlayerButton: View {
    let icon: Image
    let action: () -> Void
    var size: CGFloat = 44
    var iconSize: CGFloat = 20
    
    var body: some View {
        Button(action: action) {
            icon
                .font(.system(size: iconSize))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(
                    ZStack {
                        Color.white.opacity(0.15)
                        VisualEffectBlur(blurStyle: .systemThinMaterial)
                    }
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

// MARK: - Unified Video Progress Bar

/// A custom progress bar that shows buffered content as a grey bar behind the playback progress
/// Used consistently across all video players (Jellyfin and local)
struct UnifiedVideoProgressBar: View {
    @Binding var currentTime: Double
    let duration: Double
    let bufferedRanges: [(start: Double, end: Double)]
    let onEditingChanged: (Bool) -> Void
    
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 14
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let safeDuration = duration > 0 ? duration : 1
            let centerY = geometry.size.height / 2
            
            ZStack {
                // Background track (dark grey)
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: width, height: trackHeight)
                    .position(x: width / 2, y: centerY)
                
                // Buffer indicator (light grey/white) - shows loaded content
                ForEach(Array(bufferedRanges.enumerated()), id: \.offset) { _, range in
                    let startFraction = max(0, min(range.start / safeDuration, 1))
                    let endFraction = max(0, min(range.end / safeDuration, 1))
                    let rangeWidth = (endFraction - startFraction) * width
                    let centerX = (startFraction * width) + (rangeWidth / 2)
                    
                    if rangeWidth > 0 {
                        Capsule()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: rangeWidth, height: trackHeight)
                            .position(x: centerX, y: centerY)
                    }
                }
                
                // Progress indicator (purple)
                let progressFraction = max(0, min((isDragging ? dragValue : currentTime) / safeDuration, 1))
                let progressWidth = progressFraction * width
                
                if progressWidth > 0 {
                    Capsule()
                        .fill(Color.purple)
                        .frame(width: progressWidth, height: trackHeight)
                        .position(x: progressWidth / 2, y: centerY)
                }
                
                // Thumb/scrubber
                Circle()
                    .fill(Color.purple)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .position(x: progressFraction * width, y: centerY)
                    .scaleEffect(isDragging ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isDragging)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        
                        let fraction = max(0, min(value.location.x / width, 1))
                        dragValue = fraction * safeDuration
                        currentTime = dragValue
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEditingChanged(false)
                    }
            )
        }
    }
}

// MARK: - Player Time Label

/// Consistent time label for video players
struct PlayerTimeLabel: View {
    let time: Double
    
    var body: some View {
        Text(formatTime(time))
            .font(.caption)
            .foregroundColor(.white)
            .monospacedDigit()
    }
    
    private func formatTime(_ time: Double) -> String {
        let isNegative = time < 0
        let absTime = abs(time)
        let totalSeconds = Int(absTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        let prefix = isNegative ? "-" : ""
        
        if hours > 0 {
            return String(format: "%@%d:%02d:%02d", prefix, hours, minutes, seconds)
        }
        return String(format: "%@%02d:%02d", prefix, minutes, seconds)
    }
}
