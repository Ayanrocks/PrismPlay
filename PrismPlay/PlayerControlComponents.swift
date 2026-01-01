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
    @State private var smoothBufferedRanges: [(start: Double, end: Double)] = []
    @State private var lastBufferUpdate: Date = Date()
    
    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 14
    private let bufferUpdateThreshold: TimeInterval = 0.3
    
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
                // Use smoothBufferedRanges for stable rendering
                ForEach(Array(smoothBufferedRanges.enumerated()), id: \.offset) { _, range in
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
            .task(id: bufferedRanges.count) {
                // Update when bufferedRanges changes
                let now = Date()
                if now.timeIntervalSince(lastBufferUpdate) > bufferUpdateThreshold {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        smoothBufferedRanges = bufferedRanges
                    }
                    lastBufferUpdate = now
                }
            }
            .onAppear {
                smoothBufferedRanges = bufferedRanges
            }
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

// MARK: - Vertical Slider Component

/// A vertical slider for brightness or volume control
struct VerticalSlider: View {
    @Binding var value: Float
    let label: String
    let icon: String
    let onChange: (Float) -> Void
    
    @State private var isDragging = false
    
    private let sliderWidth: CGFloat = 4
    private let thumbSize: CGFloat = 16
    
    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            
            VStack(spacing: 8) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .opacity(isDragging ? 1.0 : 0.7)
                
                // Slider track
                ZStack(alignment: .bottom) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: sliderWidth, height: height)
                    
                    // Filled track (value indicator)
                    let fillHeight = CGFloat(value) * height
                    Capsule()
                        .fill(Color.white)
                        .frame(width: sliderWidth, height: fillHeight)
                    
                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .offset(y: -(CGFloat(value) * height - thumbSize / 2))
                        .scaleEffect(isDragging ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: isDragging)
                }
                .frame(width: sliderWidth, height: height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                            }
                            
                            // Invert Y coordinate (dragging down = lower value)
                            let newValue = Float(1.0 - min(max(gesture.location.y / height, 0), 1))
                            value = newValue
                            onChange(newValue)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
                
                // Value label
                Text("\(Int(value * 100))%")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .opacity(isDragging ? 1.0 : 0.7)
            }
        }
    }
}
