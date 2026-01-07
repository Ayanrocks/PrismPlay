import SwiftUI
import AVKit
import MediaPlayer
import Combine

/// A video player view for Jellyfin content using AVPlayer with HLS streaming
// MARK: - Video Quality
struct VideoQuality: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let bitrate: Int? // nil for "Original" (max/direct)
    
    // Default preset
    static let auto = VideoQuality(id: "auto", name: "Auto", bitrate: nil)
    
    // Standard presets for reference - we'll filter these based on source
    static let p1080 = VideoQuality(id: "1080p", name: "1080p - 10 Mbps", bitrate: 10_000_000)
    static let p720 = VideoQuality(id: "720p", name: "720p - 4 Mbps", bitrate: 4_000_000)
    static let p480 = VideoQuality(id: "480p", name: "480p - 1.5 Mbps", bitrate: 1_500_000)
    static let p360 = VideoQuality(id: "360p", name: "360p - 0.7 Mbps", bitrate: 700_000)
    
    static let allPresets = [p1080, p720, p480, p360]
}

// MARK: - Video Progress Bar removed - now using UnifiedVideoProgressBar from PlayerControlComponents.swift


struct JellyfinPlayerView: View {
    let item: JellyfinItem
    let server: JellyfinServerConfig?  // Optional server context for multi-server support
    @StateObject private var viewModel = JellyfinPlayerViewModel()
    @ObservedObject private var jellyfinService = JellyfinService.shared
    @ObservedObject private var settings = PlayerSettings.shared
    @Environment(\.dismiss) var dismiss
    
    init(item: JellyfinItem, server: JellyfinServerConfig? = nil) {
        self.item = item
        self.server = server
    }
    
    // Gesture States
    @State private var dragStartBrightness: CGFloat = 0
    @State private var dragStartVolume: Float = 0
    @State private var isDraggingBrightness = false
    @State private var isDraggingVolume = false
    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    
    // Always-visible slider values
    @State private var brightnessValue: Float = 0.5
    @State private var volumeValue: Float = 0.5
    
    // Slide-to-seek states
    @State private var isDraggingSeek = false
    @State private var seekDragStartTime: Double = 0
    @State private var seekDragOffset: Double = 0
    @State private var showSeekPreview: Bool = false
    @State private var seekDragStartLocation: CGPoint = .zero
    @State private var isFlickSeek: Bool = false // Distinguish flick from continuous drag
    
    // Double-tap feedback
    @State private var showDoubleTapFeedback: Bool = false
    @State private var doubleTapIsForward: Bool = true
    
    // Hold for 2x speed
    @State private var pressStartTime: Date? = nil
    @State private var is2xSpeedActive: Bool = false
    @State private var show2xIndicator: Bool = false
    
    // Subtitle selection
    @State private var showSubtitlePicker: Bool = false
    
    // Device orientation tracking for forced landscape
    @State private var deviceOrientation: UIDeviceOrientation = .portrait
    
    // Preferred orientation set by user (cycles through left → right → portrait)
    @State private var preferredOrientation: UIInterfaceOrientation = .landscapeLeft
    
    // Determine if we need to rotate the view to landscape
    private var shouldRotate: Bool {
        // Rotate based on preferred orientation
        switch preferredOrientation {
        case .landscapeLeft:
            return deviceOrientation.isPortrait || deviceOrientation == .unknown
        case .landscapeRight:
            return deviceOrientation.isPortrait || deviceOrientation == .unknown  
        case .portrait:
            return false  // Portrait mode - no rotation
        default:
            return deviceOrientation.isPortrait || deviceOrientation == .unknown
        }
    }
    
    // Rotation angle based on preferred orientation
    private var rotationAngle: Double {
        if !shouldRotate { return 0 }
        
        switch preferredOrientation {
        case .landscapeLeft:
            return 90  // Rotate left
        case .landscapeRight:
            return -90  // Rotate right
        default:
            return 90
        }
    }
    
    var body: some View {
        GeometryReader { outerGeometry in
            GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let player = viewModel.player {
                    VideoPlayerController(
                        player: player,
                        aspectRatio: settings.currentAspectRatio
                    )
                    .edgesIgnoringSafeArea(.all)
                    .overlay(gestureOverlay(geometry: geometry))
                    
                    // Seek Preview Overlay
                    if showSeekPreview {
                        seekPreviewOverlay()
                    }
                    
                    // Double-tap Feedback
                    if showDoubleTapFeedback {
                        doubleTapFeedbackOverlay()
                    }
                    
                    // Feedback Overlay (brightness/volume)
                    if showFeedback {
                        Text(feedbackText)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(10)
                            .transition(.opacity)
                    }
                    
                    // Custom Subtitle Overlay
                    if let subtitleText = viewModel.currentSubtitleText {
                        VStack {
                            Spacer()
                            Text(subtitleText)
                                .font(.system(size: settings.subtitleSize.fontSize, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(settings.subtitleBackgroundOpacity))
                                .cornerRadius(8)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, settings.subtitleBottomMargin)
                                .padding(.horizontal, 32)
                                .transition(.opacity)
                        }
                    }
                    
                    // Buffering indicator - small loader in corner
                    if viewModel.isBuffering {
                        VStack {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    Text("Buffering...")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    ZStack {
                                        Color.black.opacity(0.7)
                                        VisualEffectBlur(blurStyle: .systemThinMaterial)
                                    }
                                )
                                .cornerRadius(12)
                                .padding(.trailing, 16)
                                .padding(.top, geometry.safeAreaInsets.top + 60)
                            }
                            Spacer()
                        }
                    }
                    
                    // 2x Speed Indicator
                    if show2xIndicator {
                        VStack {
                            Text("2x")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(12)
                                .transition(.opacity)
                        }
                    }
                    
                    // Brightness & Volume Sliders (auto-hide with controls)
                    if viewModel.showControls {
                        GeometryReader { geo in
                            HStack {
                                // Left: Brightness Slider
                                VStack {
                                    Spacer()
                                    VerticalSlider(
                                        value: $brightnessValue,
                                        label: "Brightness",
                                        icon: "sun.max.fill",
                                        onChange: { newValue in
                                            ScreenUtils.brightness = CGFloat(newValue)
                                        }
                                    )
                                    .frame(width: 40, height: 125)
                                    Spacer()
                                }
                                .padding(.leading, 16)
                                
                                Spacer()
                                
                                // Right: Volume Slider
                                VStack {
                                    Spacer()
                                    VerticalSlider(
                                        value: $volumeValue,
                                        label: "Volume",
                                        icon: "speaker.wave.3.fill",
                                        onChange: { newValue in
                                            VolumeController.shared.setVolume(newValue)
                                        }
                                    )
                                    .frame(width: 40, height: 125)
                                    Spacer()
                                }
                                .padding(.trailing, 16)
                            }
                        }
                        .transition(.opacity)
                    }
                    
                    if viewModel.showControls {
                        controlsOverlay(geometry: geometry)
                    }
                    
                    // Subtitle loading indicator in corner
                    if viewModel.isLoadingSubtitles {
                        VStack {
                            HStack {
                                Spacer()
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.7)
                                    Text("Loading subtitles...")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                                .padding(.trailing, 16)
                                .padding(.top, geometry.safeAreaInsets.top + 60)
                            }
                            Spacer()
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        if let error = viewModel.errorMessage {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.yellow)
                            Text("Playback Error")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Close") {
                                dismiss()
                            }
                            .padding(.top, 10)
                            .buttonStyle(.bordered)
                            .tint(.white)
                        } else if viewModel.isRetrying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Playback failed, optimizing format...")
                                .foregroundColor(.white.opacity(0.9))
                                .font(.headline)
                            Text("This may take a moment")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.caption)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Loading...")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
            .rotationEffect(.degrees(rotationAngle))
            .frame(
                width: shouldRotate ? outerGeometry.size.height : outerGeometry.size.width,
                height: shouldRotate ? outerGeometry.size.width : outerGeometry.size.height
            )
            .position(
                x: outerGeometry.size.width / 2,
                y: outerGeometry.size.height / 2
            )
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            // Track device orientation
            deviceOrientation = UIDevice.current.orientation
            
            // Initialize slider values
            brightnessValue = Float(ScreenUtils.brightness)
            volumeValue = AVAudioSession.sharedInstance().outputVolume
            
            setupPlayer()
            
            // Listen for orientation changes
            NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                deviceOrientation = UIDevice.current.orientation
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
            viewModel.cleanup(itemId: item.Id, jellyfinService: jellyfinService)
        }
        .sheet(isPresented: $showSubtitlePicker) {
            subtitlePickerSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleOrientation() {
        // Cycle through: landscapeLeft → landscapeRight → portrait
        switch preferredOrientation {
        case .landscapeLeft:
            preferredOrientation = .landscapeRight
        case .landscapeRight:
            preferredOrientation = .portrait
        case .portrait:
            preferredOrientation = .landscapeLeft
        default:
            preferredOrientation = .landscapeLeft
        }
    }
    
    // MARK: - Subtitle Picker Sheet
    
    private func subtitlePickerSheet() -> some View {
        NavigationView {
            List {
                // Off option
                Button(action: {
                    viewModel.selectSubtitle(index: nil, itemId: item.Id, jellyfinService: jellyfinService)
                    showSubtitlePicker = false
                }) {
                    HStack {
                        Text("Off")
                            .foregroundColor(.primary)
                        Spacer()
                        if viewModel.selectedSubtitleIndex == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.purple)
                        }
                    }
                }
                
                // Available subtitle tracks
                ForEach(viewModel.availableSubtitles) { subtitle in
                    Button(action: {
                        viewModel.selectSubtitle(index: subtitle.Index, itemId: item.Id, jellyfinService: jellyfinService)
                        showSubtitlePicker = false
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(subtitle.subtitleDisplayName)
                                    .foregroundColor(.primary)
                                HStack(spacing: 8) {
                                    if subtitle.IsExternal == true {
                                        Text("External")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    if let codec = subtitle.Codec {
                                        Text(codec.uppercased())
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    if subtitle.IsDefault == true {
                                        Text("Default")
                                            .font(.caption2)
                                            .foregroundColor(.purple)
                                    }
                                }
                            }
                            Spacer()
                            if viewModel.selectedSubtitleIndex == subtitle.Index {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Subtitles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showSubtitlePicker = false
                    }
                }
            }
        }
    }
    
    // MARK: - Seek Preview Overlay
    
    private func seekPreviewOverlay() -> some View {
        let targetTime = seekDragStartTime + seekDragOffset
        let clampedTarget = max(0, min(targetTime, viewModel.safeDuration))
        let offsetSign = seekDragOffset >= 0 ? "+" : ""
        
        return VStack(spacing: 4) {
            Text("\(offsetSign)\(formatTime(seekDragOffset))")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text("(\(formatTime(clampedTarget)))")
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
        .transition(.opacity)
    }
    
    // MARK: - Double-tap Feedback
    
    private func doubleTapFeedbackOverlay() -> some View {
        HStack {
            if doubleTapIsForward { Spacer() }  // Forward (right) = space on left
            
            VStack(spacing: 4) {
                Image(systemName: doubleTapIsForward ? "goforward.\(Int(settings.doubleTapSeekSeconds))" : "gobackward.\(Int(settings.doubleTapSeekSeconds))")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                
                Text("\(Int(settings.doubleTapSeekSeconds))s")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(20)
            .background(Color.black.opacity(0.5))
            .clipShape(Circle())
            
            if !doubleTapIsForward { Spacer() }  // Backward (left) = space on right
        }
        .padding(.horizontal, 60)
        .transition(.opacity)
    }
    
    // MARK: - Gesture Overlay
    
    private func gestureOverlay(geometry: GeometryProxy) -> some View {
        // Single full-screen gesture overlay with comprehensive gesture handling
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                // Unified drag gesture for all interactions
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        // Start tracking press time on first touch
                        if pressStartTime == nil {
                            pressStartTime = Date()
                        }
                        
                        // Check if held for 1+ seconds for 2x speed
                        if let startTime = pressStartTime,
                           Date().timeIntervalSince(startTime) >= 1.0,
                           !is2xSpeedActive {
                            is2xSpeedActive = true
                            viewModel.player?.rate = 2.0
                            withAnimation {
                                show2xIndicator = true
                            }
                        }
                        
                        let translation = value.translation
                        let location = value.startLocation
                        let screenWidth = geometry.size.width
                        
                        // Determine if this is primarily horizontal or vertical
                        let absHorizontal = abs(translation.width)
                        let absVertical = abs(translation.height)
                        
                        // Determine zone (left 1/3, center 1/3, right 1/3)
                        let isLeftZone = location.x < screenWidth / 3
                        let isRightZone = location.x > (screenWidth * 2 / 3)
                        
                        // Only process drag gestures if there's actual movement (lower threshold for better sensitivity)
                        let hasMovement = absHorizontal > 5 || absVertical > 5
                        
                        if hasMovement {
                            if absHorizontal > absVertical {
                                // HORIZONTAL GESTURE = SEEK
                                if !isDraggingSeek {
                                    isDraggingSeek = true
                                    seekDragStartTime = viewModel.safeCurrentTime
                                    seekDragStartLocation = location
                                }
                                
                                // Continuous scrub based on drag distance
                                seekDragOffset = Double(translation.width) / settings.slideSeekSensitivity
                                
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    showSeekPreview = true
                                }
                                
                            } else {
                                // VERTICAL GESTURE = BRIGHTNESS/VOLUME (only in side zones)
                                if isLeftZone {
                                    // Left zone = brightness
                                    if !isDraggingBrightness {
                                        isDraggingBrightness = true
                                        dragStartBrightness = ScreenUtils.brightness
                                    }
                                    
                                    let delta = -translation.height / geometry.size.height
                                    let newBrightness = min(max(dragStartBrightness + delta, 0.0), 1.0)
                                    
                                    ScreenUtils.brightness = newBrightness
                                    brightnessValue = Float(newBrightness)
                                    
                                } else if isRightZone {
                                    // Right zone = volume
                                    if !isDraggingVolume {
                                        isDraggingVolume = true
                                        dragStartVolume = AVAudioSession.sharedInstance().outputVolume
                                    }
                                    
                                    let delta = Float(-translation.height / geometry.size.height)
                                    let newVolume = min(max(dragStartVolume + delta, 0.0), 1.0)
                                    
                                    VolumeController.shared.setVolume(newVolume)
                                    volumeValue = newVolume
                                }
                            }
                        }
                    }
                    .onEnded { value in
                        // ALWAYS restore normal speed when finger lifts
                        if is2xSpeedActive {
                            is2xSpeedActive = false
                            if viewModel.isPlaying {
                                viewModel.player?.rate = 1.0
                            }
                            withAnimation {
                                show2xIndicator = false
                            }
                        }
                        
                        // Reset press tracking
                        pressStartTime = nil
                        
                        // Detect if this was just a tap (no movement, quick release)
                        let translation = value.translation
                        let tapThreshold: CGFloat = 5
                        let isTap = abs(translation.width) < tapThreshold && abs(translation.height) < tapThreshold
                        
                        // If it's a tap and not dragging anything, toggle controls
                        if isTap && !isDraggingSeek && !isDraggingBrightness && !isDraggingVolume {
                            toggleControls()
                        }
                        
                        if isDraggingSeek {
                            // Apply the seek
                            let newTime = max(0, min(seekDragStartTime + seekDragOffset, viewModel.safeDuration))
                            viewModel.seek(to: newTime)
                            
                            isDraggingSeek = false
                            isFlickSeek = false
                            seekDragOffset = 0
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation {
                                    showSeekPreview = false
                                }
                            }
                        }
                        
                        if isDraggingBrightness {
                            isDraggingBrightness = false
                            dragStartBrightness = 0
                        }
                        
                        if isDraggingVolume {
                            isDraggingVolume = false
                            dragStartVolume = 0
                        }
                    }
            )
            .onTapGesture(count: 2, perform: {
                toggleControls()
            })
            .onTapGesture(count: 1) {
                toggleControls()
            }
    }
    
    // MARK: - Controls Overlay
    
    private func controlsOverlay(geometry: GeometryProxy) -> some View {
        GeometryReader { _ in
            ZStack {
                // Top Bar
                VStack {
                    HStack(spacing: 12) {
                        // Close button
                        GlassmorphicPlayerButton(
                            icon: PrismIcon.close.image,
                            action: {
                                viewModel.resetOrientation()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    dismiss()
                                }
                            },
                            size: 44,
                            iconSize: 22
                        )
                        
                        Spacer()
                        
                        // Title
                        VStack(spacing: 2) {
                            Text(item.Name)
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            if let seriesName = item.SeriesName {
                                Text(seriesName)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        Spacer()
                        
                        // Quick Access Buttons
                        HStack(spacing: 8) {
                            // Aspect Ratio
                            GlassmorphicPlayerButton(
                                icon: Image(systemName: settings.currentAspectRatio.iconName),
                                action: { _ = settings.cycleAspectRatio() },
                                size: 40,
                                iconSize: 18
                            )
                            
                            // Subtitles
                            GlassmorphicPlayerButton(
                                icon: Image(systemName: viewModel.selectedSubtitleIndex != nil ? "captions.bubble.fill" : "captions.bubble"),
                                action: { showSubtitlePicker = true },
                                size: 40,
                                iconSize: 18
                            )
                            
                            // Rotate Screen
                            GlassmorphicPlayerButton(
                                icon: Image(systemName: "rotate.right"),
                                action: { toggleOrientation() },
                                size: 40,
                                iconSize: 18
                            )
                            
                            // Quality Menu (Settings)
                            Menu {
                                ForEach(viewModel.availableQualities) { quality in
                                    Button(action: { viewModel.changeQuality(to: quality, jellyfinService: jellyfinService) }) {
                                        HStack {
                                            Text(quality.name)
                                            if viewModel.selectedQuality == quality {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(.white)
                                    .font(.title3)
                                    .padding(10)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 16)
                    
                    Spacer()
                }
                
                // Center Controls
                HStack(spacing: 50) {
                    Button(action: { viewModel.seekRelative(by: -settings.skipButtonSeconds) }) {
                        PrismIcon.seekBackward.image
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                    }
                    
                    Button(action: { viewModel.togglePlayPause(itemId: item.Id, jellyfinService: jellyfinService) }) {
                        (viewModel.isPlaying ? PrismIcon.pause.image : PrismIcon.play.image)
                            .font(.system(size: 70))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                    }
                    
                    Button(action: { viewModel.seekRelative(by: settings.skipButtonSeconds) }) {
                        PrismIcon.seekForward.image
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                    }
                }
                
                // Bottom Bar
                VStack {
                    Spacer()
                    
                    HStack {
                        PlayerTimeLabel(time: viewModel.safeCurrentTime)
                        
                        UnifiedVideoProgressBar(
                            currentTime: Binding(
                                get: { viewModel.safeCurrentTime },
                                set: { viewModel.safeCurrentTime = $0 }
                            ),
                            duration: viewModel.safeDuration,
                            bufferedRanges: viewModel.bufferedRanges,
                            onEditingChanged: { editing in
                                viewModel.isSeeking = editing
                                if !editing {
                                    viewModel.seek(to: viewModel.safeCurrentTime)
                                }
                            }
                        )
                        .frame(height: 30) // Touch target area
                        
                        PlayerTimeLabel(time: viewModel.safeDuration)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
                    .background(
                        LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                    )
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .transition(.opacity)
    }
    
    // MARK: - Helper Methods
    
    private func setupPlayer() {
        // We no longer manually get streamURL here; let the ViewModel handle it
        let resumePosition = item.UserData?.playbackPositionSeconds ?? 0
        
        viewModel.setupPlayer(
            itemId: item.Id,
            resumePosition: resumePosition,
            jellyfinService: jellyfinService,
            item: item,
            server: server  // Pass server context for multi-server support
        )
        
        // Determine available qualities based on the item
        viewModel.determineAvailableQualities(for: item)
    }
    
    private func toggleControls() {
        withAnimation {
            viewModel.showControls.toggle()
        }
        viewModel.resetControlTimer()
    }
    
    private func handleDoubleTap(isForward: Bool) {
        doubleTapIsForward = isForward
        let seekAmount = isForward ? settings.doubleTapSeekSeconds : -settings.doubleTapSeekSeconds
        viewModel.seekRelative(by: seekAmount)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showDoubleTapFeedback = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation {
                showDoubleTapFeedback = false
            }
        }
    }
    
    private func showFeedback(text: String) {
        feedbackText = text
        withAnimation {
            showFeedback = true
        }
    }
    
    private func hideFeedback() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                showFeedback = false
            }
        }
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

// MARK: - Volume Controller (Singleton)

class VolumeController: NSObject {
    static let shared = VolumeController()
    
    private var volumeView: MPVolumeView!
    private var volumeSlider: UISlider?
    
    private override init() {
        super.init()
        setupVolumeView()
    }
    
    private func setupVolumeView() {
        volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 100, height: 40))
        volumeView.showsVolumeSlider = true
        // volumeView.showsRouteButton = false // Deprecated in iOS 13
        
        // Find the slider in the volume view
        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                volumeSlider = slider
                break
            }
        }
        
        // Add to window so it's active
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.addSubview(volumeView)
        }
    }
    
    func setVolume(_ volume: Float) {
        DispatchQueue.main.async { [weak self] in
            self?.volumeSlider?.value = volume
            self?.volumeSlider?.sendActions(for: .valueChanged)
        }
    }
    
    func getVolume() -> Float {
        return AVAudioSession.sharedInstance().outputVolume
    }
}

// MARK: - ViewModel

class JellyfinPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 1
    @Published var showControls = true
    @Published var isSeeking = false
    @Published var availableSubtitles: [MediaStream] = []
    @Published var selectedSubtitleIndex: Int? = nil
    @Published var isLoadingSubtitles: Bool = false
    @Published var currentSubtitleText: String? = nil
    @Published var selectedQuality: VideoQuality = .auto
    @Published var availableQualities: [VideoQuality] = []
    @Published var errorMessage: String? = nil
    @Published var isRetrying: Bool = false
    @Published var isBuffering: Bool = false
    
    // Buffer indicator - tracks loaded time ranges from AVPlayer
    @Published var bufferedRanges: [(start: Double, end: Double)] = []
    
    private var currentProfile: PlaybackProfile = .high
    private var subtitleCues: [SubtitleCue] = []
    
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var bufferingObserver: NSKeyValueObservation?
    private var controlTimer: Timer?
    private var progressReportTimer: Timer?
    private var currentItemId: String?
    private var currentMediaSourceId: String?
    private var currentItem: JellyfinItem? // Keep reference for retries
    private var currentServer: JellyfinServerConfig? // Server context for multi-server support
    
    // HLS Cache integration
    private let hlsCacheController = HLSCacheController.shared
    private var cacheSubscription: AnyCancellable?
    
    /// Safe duration value that's never NaN, negative, or zero
    
    /// Safe duration value that's never NaN, negative, or zero
    var safeDuration: Double {
        let d = duration
        if d.isNaN || d.isInfinite || d <= 0 {
            return 1
        }
        return d
    }
    
    /// Safe current time clamped to valid range
    var safeCurrentTime: Double {
        get {
            let t = currentTime
            if t.isNaN || t.isInfinite || t < 0 {
                return 0
            }
            return min(t, safeDuration)
        }
        set {
            currentTime = max(0, min(newValue, safeDuration))
        }
    }
    
    func setupPlayer(with url: URL? = nil, itemId: String, resumePosition: Double, jellyfinService: JellyfinService, item: JellyfinItem, server: JellyfinServerConfig? = nil) {
        self.currentItemId = itemId
        self.currentItem = item
        self.currentMediaSourceId = item.MediaSources?.first?.Id
        self.currentServer = server  // Store server context
        
        // Start with direct streaming for best quality (native HEVC/H.264)
        // Fallback cascade: direct → high (HLS HEVC) → compatible (H.264 transcode)
        self.currentProfile = .direct
        
        loadPlayer(itemId: itemId, resumePosition: resumePosition, jellyfinService: jellyfinService)
    }
    
    private func loadPlayer(itemId: String, resumePosition: Double, jellyfinService: JellyfinService) {
        // Get URL based on current profile
        let streamURL: URL?
        
        if let server = currentServer {
            // Use server-specific methods for multi-server support
            if currentProfile == .direct {
                streamURL = jellyfinService.getDirectStreamURL(itemId: itemId, for: server)
            } else {
                streamURL = jellyfinService.getStreamURL(itemId: itemId, for: server, profile: currentProfile, maxBitrate: selectedQuality.bitrate)
            }
        } else {
            // Fall back to default server methods
            if currentProfile == .direct {
                streamURL = jellyfinService.getDirectStreamURL(itemId: itemId)
            } else {
                streamURL = jellyfinService.getStreamURL(itemId: itemId, profile: currentProfile, maxBitrate: selectedQuality.bitrate)
            }
        }
        
        guard let url = streamURL else {
            self.errorMessage = "Could not generate stream URL"
            return
        }
        
        print("Loading player with profile: \(currentProfile), URL: \(url)")
        
        // Start loading subtitles (only on first load ideally, but harmless to re-check)
        if availableSubtitles.isEmpty {
           loadSubtitles(jellyfinService: jellyfinService, itemId: itemId, item: currentItem)
        }
        
        // Use standard AVURLAsset (caching disabled due to HLS incompatibility)
        let playerItem = AVPlayerItem(url: url)
        
        // Start HLS caching for non-direct streams
        if currentProfile != .direct {
            hlsCacheController.startCaching(for: url)
            
            // Subscribe to cache ranges updates
            cacheSubscription = hlsCacheController.$cachedRanges
                .receive(on: DispatchQueue.main)
                .sink { [weak self] ranges in
                    self?.bufferedRanges = ranges.map { (start: $0.lowerBound, end: $0.upperBound) }
                }
        }
        
        // --- End Player Setup ---
        
        // Observe status for errors
        statusObserver = playerItem.observe(\.status, options: [.new, .old]) { [weak self] item, _ in
            guard let self = self else { return }
            
            switch item.status {
            case .failed:
                let error = item.error
                print("Player item failed: \(String(describing: error))")
                
                // Smart Fallback Logic: direct → high → compatible
                if self.currentProfile == .direct {
                    print("Smart Fallback: direct stream failed, trying HLS HEVC...")
                    DispatchQueue.main.async {
                        self.retryWithProfile(.high, jellyfinService: jellyfinService, resumePosition: self.currentTime > 0 ? self.currentTime : resumePosition)
                    }
                } else if self.currentProfile == .high {
                    print("Smart Fallback: HLS HEVC failed, trying H.264 compatible...")
                    DispatchQueue.main.async {
                        self.retryWithProfile(.compatible, jellyfinService: jellyfinService, resumePosition: self.currentTime > 0 ? self.currentTime : resumePosition)
                    }
                } else {
                    // Compatible also failed, show error
                    DispatchQueue.main.async {
                        self.isRetrying = false
                        self.errorMessage = error?.localizedDescription ?? "Playback failed"
                        self.player = nil
                    }
                }
                
            case .readyToPlay:
                DispatchQueue.main.async {
                    self.errorMessage = nil
                    self.isRetrying = false
                }
            default:
                break
            }
        }
        
        // Notification for "Safe" failure (NewErrorLogEntry) - sometimes .failed isn't triggered immediately for network format errors
        NotificationCenter.default.addObserver(forName: .AVPlayerItemNewErrorLogEntry, object: playerItem, queue: .main) { [weak self] notification in
            guard let self = self, let object = notification.object as? AVPlayerItem, object == self.player?.currentItem else { return }
            guard let log = object.errorLog(), let lastEvent = log.events.last else { return }
            
            print("AVPlayer Error Log: \(lastEvent.errorComment ?? "Unknown")")
            
            // If we are seeing errors, and haven't failed hard yet, consider fallback if it stalls.
            // But strict failure is safer to trigger on. We'll rely on status .failed for now.
        }
        
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        // Observe buffering state via timeControlStatus
        bufferingObserver = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }
        
        // Disable automatic media selection to allow manual subtitle control
        player?.appliesMediaSelectionCriteriaAutomatically = false
        
        // Report playback start
        let startPositionTicks = Int64(resumePosition * 10_000_000)
        jellyfinService.reportPlaybackStart(itemId: itemId, positionTicks: startPositionTicks)
        
        // Time observer for progress tracking and subtitles
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            if !self.isSeeking {
                self.currentTime = CMTimeGetSeconds(time)
                
                // Update subtitle text
                if !self.subtitleCues.isEmpty {
                    let currentSeconds = self.currentTime
                    if let cue = self.subtitleCues.first(where: { currentSeconds >= $0.startTime && currentSeconds <= $0.endTime }) {
                        if self.currentSubtitleText != cue.text {
                            self.currentSubtitleText = cue.text
                        }
                    } else {
                        if self.currentSubtitleText != nil {
                            self.currentSubtitleText = nil
                        }
                    }
                }
            }
            
            // Update duration from player item
            if let currentItem = self.player?.currentItem {
                let dur = CMTimeGetSeconds(currentItem.duration)
                if !dur.isNaN && dur > 0 {
                    self.duration = dur
                }
                
                // Always update buffered ranges from AVPlayer for buffer indicator
                // This shows what AVPlayer has loaded in memory (works for all stream types)
                let loadedRanges = currentItem.loadedTimeRanges.compactMap { value -> (start: Double, end: Double)? in
                    let range = value.timeRangeValue
                    let start = CMTimeGetSeconds(range.start)
                    let end = start + CMTimeGetSeconds(range.duration)
                    guard !start.isNaN && !end.isNaN && end > start else { return nil }
                    return (start: start, end: end)
                }
                
                // Update buffer ranges for display
                self.bufferedRanges = loadedRanges
                
                // Also update HLS cache controller for actual segment caching (HLS streams only)
                if self.currentProfile != .direct {
                    self.hlsCacheController.updatePlaybackTime(self.currentTime)
                }
            }
        }
        
        // Seek to resume position if any
        if resumePosition > 0 {
            let cmTime = CMTime(seconds: resumePosition, preferredTimescale: 600)
            player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        
        // Start periodic progress reporting (every 10 seconds)
        progressReportTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            let positionTicks = Int64(CMTimeGetSeconds(player.currentTime()) * 10_000_000)
            let isPaused = !self.isPlaying
            
            Task { @MainActor in
               jellyfinService.reportPlaybackProgress(itemId: itemId, positionTicks: positionTicks, isPaused: isPaused)
            }
        }
        
        player?.play()
        isPlaying = true
        resetControlTimer()
        
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    func changeQuality(to quality: VideoQuality, jellyfinService: JellyfinService) {
        guard selectedQuality != quality, let itemId = currentItemId else { return }
        
        let resumeTime = safeCurrentTime
        selectedQuality = quality
        
        // Stop current player but keep state
        player?.pause()
        
        guard let streamURL = jellyfinService.getStreamURL(itemId: itemId, profile: currentProfile, maxBitrate: quality.bitrate) else {
            return
        }
        
        let playerItem = AVPlayerItem(url: streamURL)
        player?.replaceCurrentItem(with: playerItem)
        
        // Seek to previous position
        let cmTime = CMTime(seconds: resumeTime, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        
        // Restore subtitle selection if needed
        // Subtitle tracks are separate from video variants in Jellyfin HLS usually,
        // but if we reload the item we might need to re-apply the external text track.
        // Since we are just replacing the item, we might need to re-select the subtitle.
        // For simplicity, we'll just let the user re-select if it drops, or we can improve this later.
        // However, since we store selectedSubtitleIndex, we can try to re-apply it.
        if let subIndex = selectedSubtitleIndex {
            // Re-apply subtitle logic after a short delay or state update mechanism
            // For now, simpler is better. The view will re-render.
            selectSubtitle(index: subIndex, itemId: itemId, jellyfinService: jellyfinService)
        }
        
        if isPlaying {
            player?.play()
        }
    }
    
    func selectSubtitle(index: Int?, itemId: String, jellyfinService: JellyfinService) {
        // Reset current subtitles
        self.subtitleCues = []
        self.currentSubtitleText = nil
        
        guard let playerItem = player?.currentItem else { return }
        
        if let subtitleIndex = index {
            self.selectedSubtitleIndex = subtitleIndex
            
            // Get subtitle URL from Jellyfin
            if let subtitleURL = jellyfinService.getSubtitleURL(
                itemId: itemId,
                mediaSourceId: currentMediaSourceId,
                subtitleIndex: subtitleIndex
            ) {
                print("Loading external subtitle from: \(subtitleURL)")
                self.isLoadingSubtitles = true
                
                // Fetch and parse VTT content
                Task {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: subtitleURL)
                        if let content = String(data: data, encoding: .utf8) {
                            print("Fetched subtitle content (first 200 chars): \(content.prefix(200))")
                            let cues = SubtitleParser.parseWebVTT(content)
                            
                            await MainActor.run {
                                self.subtitleCues = cues
                                self.isLoadingSubtitles = false
                                print("Parsed \(cues.count) subtitle cues")
                            }
                        } else {
                            print("Failed to decode subtitle content")
                            await MainActor.run { self.isLoadingSubtitles = false }
                        }
                    } catch {
                        print("Failed to fetch subtitle content: \(error)")
                        await MainActor.run { self.isLoadingSubtitles = false }
                    }
                }
                
                // Disable embedded tracks to avoid double subtitles if AVPlayer happens to support them
                Task { @MainActor in
                    do {
                        let asset = playerItem.asset
                        if let group = try await asset.loadMediaSelectionGroup(for: .legible) {
                            playerItem.select(nil, in: group)
                        }
                    } catch {
                         // ignore errors here
                    }
                }
            }
        } else {
            // Disable subtitles
            self.selectedSubtitleIndex = nil
            self.subtitleCues = []
            self.currentSubtitleText = nil
            
            Task { @MainActor in
                do {
                    let asset = playerItem.asset
                    if let group = try await asset.loadMediaSelectionGroup(for: .legible) {
                        playerItem.select(nil, in: group)
                    }
                } catch {
                    print("Failed to disable subtitles: \(error)")
                }
                print("Subtitles disabled")
            }
        }
    }
    
    func togglePlayPause(itemId: String, jellyfinService: JellyfinService) {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            let positionTicks = Int64(CMTimeGetSeconds(player.currentTime()) * 10_000_000)
            jellyfinService.reportPlaybackProgress(itemId: itemId, positionTicks: positionTicks, isPaused: true)
        } else {
            player.play()
        }
        isPlaying.toggle()
        resetControlTimer()
    }
    
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        resetControlTimer()
    }
    
    func seekRelative(by seconds: Double) {
        if let player = player {
            let currentTime = CMTimeGetSeconds(player.currentTime())
            let newTime = max(0, min(currentTime + seconds, duration))
            seek(to: newTime)
        }
    }
    
    func resetControlTimer() {
        controlTimer?.invalidate()
        if isPlaying {
            controlTimer = Timer.scheduledTimer(withTimeInterval: PlayerSettings.shared.controlsAutoHideDelay, repeats: false) { [weak self] _ in
                withAnimation {
                    self?.showControls = false
                }
            }
        }
    }
    
    func cleanup(itemId: String, jellyfinService: JellyfinService) {
        // Report final position
        if let player = player {
            let positionTicks = Int64(CMTimeGetSeconds(player.currentTime()) * 10_000_000)
            jellyfinService.reportPlaybackStopped(itemId: itemId, positionTicks: positionTicks)
        }
        
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        
        // Stop and clear HLS cache
        cacheSubscription?.cancel()
        cacheSubscription = nil
        hlsCacheController.stop()
        
        statusObserver = nil
        bufferingObserver = nil
        progressReportTimer?.invalidate()
        controlTimer?.invalidate()
        player?.pause()
        player = nil
        
        resetOrientation()
    }
    
    // MARK: - Quality Management
    
    func determineAvailableQualities(for item: JellyfinItem) {
        // Defaults
        var qualities: [VideoQuality] = []
        
        // Find the primary video stream to get source stats
        var sourceBitrate: Int = Int.max
        var sourceHeight: Int = 1080
        var sourceName = "Original"
        
        if let mediaSource = item.MediaSources?.first,
           let videoStream = mediaSource.MediaStreams?.first(where: { $0.StreamType == "Video" }) {
            
            // Use bitrate if available, otherwise assume high
            sourceBitrate = videoStream.BitRate ?? 100_000_000
            sourceHeight = videoStream.Height ?? 1080
            
            // Construct a nice name for Original
            let resolution = videoStream.Height != nil ? "\(videoStream.Height!)p" : "Source"
            let bitrate = videoStream.BitRate != nil ? "\(videoStream.BitRate! / 1_000_000) Mbps" : "Direct"
            sourceName = "Original (\(resolution) - \(bitrate))"
        }
        
        // Add Original/Auto option
        let original = VideoQuality(id: "auto", name: sourceName, bitrate: nil)
        qualities.append(original)
        
        // Filter presets
        for preset in VideoQuality.allPresets {
             if let presetBitrate = preset.bitrate {
                 // Include if bitrate is significantly lower
                 if presetBitrate < sourceBitrate {
                     // Parse height from id "1080p" -> 1080
                     let presetHeightStr = preset.id.replacingOccurrences(of: "p", with: "")
                     let presetHeight = Int(presetHeightStr) ?? 0
                     
                     if presetHeight <= sourceHeight || presetHeight == 0 {
                         qualities.append(preset)
                     }
                 }
             }
        }
        
        DispatchQueue.main.async {
            self.availableQualities = qualities
            // Ensure selected quality is valid, if not, reset to auto/original
            if !qualities.contains(self.selectedQuality) {
                self.selectedQuality = original
            }
        }
    }
    

    
    func forceOrientation(_ orientation: UIInterfaceOrientation) {
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            
            if orientation.isLandscape {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
            } else {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
        } else {
            UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
        }
    }
    
    func resetOrientation() {
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
    }
    
    // MARK: - Helper Methods
    
    private func retryWithProfile(_ profile: PlaybackProfile, jellyfinService: JellyfinService, resumePosition: Double) {
        isRetrying = true
        currentProfile = profile
        
        if let itemId = currentItemId {
            loadPlayer(itemId: itemId, resumePosition: resumePosition, jellyfinService: jellyfinService)
        }
    }

    private func loadSubtitles(jellyfinService: JellyfinService, itemId: String, item: JellyfinItem?) {
        guard let item = item else { return }
        
        isLoadingSubtitles = true
        
        // Try to load subtitles from the passed item first
        let subtitlesFromItem = jellyfinService.getSubtitleStreams(from: item)
        if !subtitlesFromItem.isEmpty {
            self.availableSubtitles = subtitlesFromItem
            self.isLoadingSubtitles = false
            print("Subtitles from item: \(subtitlesFromItem.map { $0.subtitleDisplayName })")
        } else {
            // Fetch full item details
            jellyfinService.getItemDetails(itemId: itemId) { [weak self] detailedItem in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let detailedItem = detailedItem {
                        if let mediaSource = detailedItem.MediaSources?.first,
                           let streams = mediaSource.MediaStreams {
                            self.availableSubtitles = streams.filter { $0.StreamType == "Subtitle" }
                        }
                        if let defaultSub = self.availableSubtitles.first(where: { $0.IsDefault == true }) {
                            self.selectSubtitle(index: defaultSub.Index, itemId: itemId, jellyfinService: jellyfinService)
                        }
                    }
                    self.isLoadingSubtitles = false
                }
            }
        }
    }
}
