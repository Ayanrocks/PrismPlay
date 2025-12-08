import SwiftUI
import AVKit
import MediaPlayer
import Combine

/// A video player view for Jellyfin content using AVPlayer with HLS streaming
struct JellyfinPlayerView: View {
    let item: JellyfinItem
    @StateObject private var viewModel = JellyfinPlayerViewModel()
    @ObservedObject private var jellyfinService = JellyfinService.shared
    @Environment(\.dismiss) var dismiss
    
    // Gesture States
    @State private var dragStartBrightness: CGFloat = 0
    @State private var dragStartVolume: Float = 0
    @State private var isDraggingBrightness = false
    @State private var isDraggingVolume = false
    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let player = viewModel.player {
                    VideoPlayerController(player: player)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(gestureOverlay(geometry: geometry))
                    
                    // Feedback Overlay
                    if showFeedback {
                        Text(feedbackText)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(10)
                            .transition(.opacity)
                    }
                    
                    if viewModel.showControls {
                        controlsOverlay(geometry: geometry)
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
    }
    
    // MARK: - Gesture Overlay
    
    private func gestureOverlay(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left Side: Brightness
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
                .onTapGesture { toggleControls() }
            
            // Center: Tap Only
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { toggleControls() }
            
            // Right Side: Volume
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
                .onTapGesture { toggleControls() }
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
                Button(action: { viewModel.seekRelative(by: -10) }) {
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
                
                Button(action: { viewModel.seekRelative(by: 10) }) {
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
            jellyfinService: jellyfinService
        )
    }
    
    private func toggleControls() {
        withAnimation {
            viewModel.showControls.toggle()
        }
        viewModel.resetControlTimer()
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
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
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
    
    private var timeObserver: Any?
    private var controlTimer: Timer?
    private var progressReportTimer: Timer?
    private var currentItemId: String?
    
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
    
    func setupPlayer(with url: URL, itemId: String, resumePosition: Double, jellyfinService: JellyfinService) {
        currentItemId = itemId
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Report playback start
        let startPositionTicks = Int64(resumePosition * 10_000_000)
        jellyfinService.reportPlaybackStart(itemId: itemId, positionTicks: startPositionTicks)
        
        // Time observer for progress tracking
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self, !self.isSeeking else { return }
            self.currentTime = CMTimeGetSeconds(time)
            
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
            controlTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
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
