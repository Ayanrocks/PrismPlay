import SwiftUI
import AVKit
import MediaPlayer
import Combine

/// A video player view for Jellyfin content using AVPlayer with HLS streaming
struct JellyfinPlayerView: View {
    let item: JellyfinItem
    @StateObject private var viewModel = JellyfinPlayerViewModel()
    @ObservedObject private var jellyfinService = JellyfinService.shared
    @ObservedObject private var settings = PlayerSettings.shared
    @Environment(\.dismiss) var dismiss
    
    // Gesture States
    @State private var dragStartBrightness: CGFloat = 0
    @State private var dragStartVolume: Float = 0
    @State private var isDraggingBrightness = false
    @State private var isDraggingVolume = false
    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    
    // Slide-to-seek states
    @State private var isDraggingSeek = false
    @State private var seekDragStartTime: Double = 0
    @State private var seekDragOffset: Double = 0
    @State private var showSeekPreview: Bool = false
    
    // Double-tap feedback
    @State private var showDoubleTapFeedback: Bool = false
    @State private var doubleTapIsForward: Bool = true
    
    // Subtitle selection
    @State private var showSubtitlePicker: Bool = false
    
    var body: some View {
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
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 20)
                                .padding(.horizontal, 32)
                                .transition(.opacity)
                        }
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
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Loading...")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            viewModel.cleanup(itemId: item.Id, jellyfinService: jellyfinService)
        }
        .sheet(isPresented: $showSubtitlePicker) {
            subtitlePickerSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
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
            if !doubleTapIsForward { Spacer() }
            
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
            
            if doubleTapIsForward { Spacer() }
        }
        .padding(.horizontal, 60)
        .transition(.opacity)
    }
    
    // MARK: - Gesture Overlay
    
    private func gestureOverlay(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left Side: Brightness + Double-tap backward
            Color.clear
                .contentShape(Rectangle())
                .frame(width: geometry.size.width / 3)
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            if !isDraggingBrightness {
                                isDraggingBrightness = true
                                dragStartBrightness = UIScreen.main.brightness
                            }
                            
                            let delta = -value.translation.height / geometry.size.height
                            let newBrightness = min(max(dragStartBrightness + delta, 0.0), 1.0)
                            
                            UIScreen.main.brightness = newBrightness
                            showFeedback(text: "Brightness: \(Int(newBrightness * 100))%")
                        }
                        .onEnded { _ in
                            isDraggingBrightness = false
                            dragStartBrightness = 0
                            hideFeedback()
                        }
                )
                .onTapGesture(count: 2) {
                    handleDoubleTap(isForward: false)
                }
                .onTapGesture(count: 1) {
                    toggleControls()
                }
            
            // Center: Slide-to-seek + Tap
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onChanged { value in
                            if !isDraggingSeek {
                                isDraggingSeek = true
                                seekDragStartTime = viewModel.safeCurrentTime
                            }
                            
                            // Calculate seek offset based on horizontal drag
                            let dragDistance = value.translation.width
                            seekDragOffset = Double(dragDistance) / settings.slideSeekSensitivity
                            
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showSeekPreview = true
                            }
                        }
                        .onEnded { _ in
                            if isDraggingSeek {
                                // Apply the seek
                                let newTime = max(0, min(seekDragStartTime + seekDragOffset, viewModel.safeDuration))
                                viewModel.seek(to: newTime)
                                
                                isDraggingSeek = false
                                seekDragOffset = 0
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation {
                                        showSeekPreview = false
                                    }
                                }
                            }
                        }
                )
                .onTapGesture { toggleControls() }
            
            // Right Side: Volume + Double-tap forward
            Color.clear
                .contentShape(Rectangle())
                .frame(width: geometry.size.width / 3)
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            if !isDraggingVolume {
                                isDraggingVolume = true
                                dragStartVolume = AVAudioSession.sharedInstance().outputVolume
                            }
                            
                            let delta = Float(-value.translation.height / geometry.size.height)
                            let newVolume = min(max(dragStartVolume + delta, 0.0), 1.0)
                            
                            VolumeController.shared.setVolume(newVolume)
                            showFeedback(text: "Volume: \(Int(newVolume * 100))%")
                        }
                        .onEnded { _ in
                            isDraggingVolume = false
                            dragStartVolume = 0
                            hideFeedback()
                        }
                )
                .onTapGesture(count: 2) {
                    handleDoubleTap(isForward: true)
                }
                .onTapGesture(count: 1) {
                    toggleControls()
                }
        }
    }
    
    // MARK: - Controls Overlay
    
    private func controlsOverlay(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top Bar - positioned at safe area top
            HStack {
                Button(action: {
                    viewModel.resetOrientation()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        dismiss()
                    }
                }) {
                    PrismIcon.close.image
                        .foregroundColor(.white)
                        .font(.title2)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                
                Spacer()
                
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
                
                // Aspect Ratio Button
                Button(action: {
                    _ = settings.cycleAspectRatio()
                }) {
                    Image(systemName: settings.currentAspectRatio.iconName)
                        .foregroundColor(.white)
                        .font(.title2)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                
                // Subtitle Button
                Button(action: {
                    showSubtitlePicker = true
                }) {
                    Image(systemName: viewModel.selectedSubtitleIndex != nil ? "captions.bubble.fill" : "captions.bubble")
                        .foregroundColor(viewModel.selectedSubtitleIndex != nil ? .purple : .white)
                        .font(.title2)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                
                Button(action: {
                    viewModel.toggleOrientation()
                }) {
                    PrismIcon.rotateScreen.image
                        .foregroundColor(.white)
                        .font(.title2)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 16)
            
            Spacer()
            
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
            
            Spacer()
            
            // Bottom Controls
            VStack(spacing: 0) {
                HStack {
                    Text(formatTime(viewModel.safeCurrentTime))
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Slider(value: Binding(
                        get: { viewModel.safeCurrentTime },
                        set: { viewModel.safeCurrentTime = $0 }
                    ), in: 0...viewModel.safeDuration, onEditingChanged: { editing in
                        viewModel.isSeeking = editing
                        if !editing {
                            viewModel.seek(to: viewModel.safeCurrentTime)
                        }
                    })
                    .accentColor(.purple)
                    
                    Text(formatTime(viewModel.safeDuration))
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
            )
            .padding(.bottom, geometry.safeAreaInsets.bottom)
        }
        .transition(.opacity)
    }
    
    // MARK: - Helper Methods
    
    private func setupPlayer() {
        guard let streamURL = jellyfinService.getStreamURL(itemId: item.Id) else {
            print("Failed to get stream URL for item: \(item.Id)")
            return
        }
        
        // Get resume position from UserData if available
        let resumePosition = item.UserData?.playbackPositionSeconds ?? 0
        
        viewModel.setupPlayer(
            with: streamURL,
            itemId: item.Id,
            resumePosition: resumePosition,
            jellyfinService: jellyfinService,
            item: item
        )
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
        volumeView.showsRouteButton = false
        
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
    
    private var subtitleCues: [SubtitleCue] = []
    
    private var timeObserver: Any?
    private var controlTimer: Timer?
    private var progressReportTimer: Timer?
    private var currentItemId: String?
    private var currentMediaSourceId: String?
    
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
    
    func setupPlayer(with url: URL, itemId: String, resumePosition: Double, jellyfinService: JellyfinService, item: JellyfinItem) {
        currentItemId = itemId
        currentMediaSourceId = item.MediaSources?.first?.Id
        
        // Start loading subtitles
        isLoadingSubtitles = true
        
        // Try to load subtitles from the passed item first
        let subtitlesFromItem = jellyfinService.getSubtitleStreams(from: item)
        if !subtitlesFromItem.isEmpty {
            availableSubtitles = subtitlesFromItem
            isLoadingSubtitles = false
            print("Subtitles from item: \(availableSubtitles.map { $0.subtitleDisplayName })")
        } else {
            // Fetch full item details from server to get MediaStreams
            print("No subtitles in item, fetching from server...")
            jellyfinService.getItemDetails(itemId: itemId) { [weak self] detailedItem in
                guard let self = self else { return }
                if let detailedItem = detailedItem {
                    // Extract subtitles directly from the item to avoid actor isolation issues
                    if let mediaSource = detailedItem.MediaSources?.first,
                       let streams = mediaSource.MediaStreams {
                        self.availableSubtitles = streams.filter { $0.StreamType == "Subtitle" }
                    }
                    self.currentMediaSourceId = detailedItem.MediaSources?.first?.Id
                    print("Subtitles from server: \(self.availableSubtitles.map { $0.subtitleDisplayName })")
                    
                    // Auto-enable default subtitle if available
                    if let defaultSub = self.availableSubtitles.first(where: { $0.IsDefault == true }) {
                        self.selectSubtitle(index: defaultSub.Index, itemId: itemId, jellyfinService: jellyfinService)
                    }
                } else {
                    print("Failed to fetch item details for subtitles")
                }
                self.isLoadingSubtitles = false
            }
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
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
            jellyfinService.reportPlaybackProgress(itemId: itemId, positionTicks: positionTicks, isPaused: !self.isPlaying)
        }
        
        player?.play()
        isPlaying = true
        resetControlTimer()
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
        progressReportTimer?.invalidate()
        controlTimer?.invalidate()
        player?.pause()
        player = nil
        
        resetOrientation()
    }
    
    func toggleOrientation() {
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            
            if windowScene.effectiveGeometry.interfaceOrientation.isLandscape {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            } else {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
            }
        } else {
            let currentOrientation = UIDevice.current.orientation
            let value = currentOrientation.isLandscape ? UIInterfaceOrientation.portrait.rawValue : UIInterfaceOrientation.landscapeRight.rawValue
            UIDevice.current.setValue(value, forKey: "orientation")
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
}
