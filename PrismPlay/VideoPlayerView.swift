import SwiftUI
import AVKit
import Combine
import UIKit
import MediaPlayer

struct VideoPlayerView: View {
    let url: URL
    @StateObject private var viewModel = PlayerViewModel()
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var settings = PlayerSettings.shared
    
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
    
    // Volume Control
    @State private var targetVolume: Float = AVAudioSession.sharedInstance().outputVolume
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if let player = viewModel.player {
                VideoPlayerController(
                    player: player,
                    aspectRatio: settings.currentAspectRatio
                )
                .edgesIgnoringSafeArea(.all)
                .overlay(gestureOverlay())
                
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

                if viewModel.showControls {
                    controlsOverlay()
                }
                
                // Hidden Volume View to enable programmatic control via binding
                VolumeView(volume: $targetVolume)
                    .frame(width: 0, height: 0)
                    .opacity(0.001)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .onAppear {
            viewModel.setupPlayer(with: url)
        }
        .onDisappear {
            viewModel.cleanup()
            viewModel.resetOrientation()
        }
    }
    
    // MARK: - Gesture Overlay
    
    private func gestureOverlay() -> some View {
        GeometryReader { geometry in
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
                                    dragStartBrightness = ScreenUtils.brightness
                                }
                                
                                let delta = -value.translation.height / geometry.size.height
                                let newBrightness = min(max(dragStartBrightness + delta, 0.0), 1.0)
                                
                                ScreenUtils.brightness = newBrightness
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
                                    seekDragStartTime = viewModel.currentTime
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
                                    let newTime = max(0, min(seekDragStartTime + seekDragOffset, viewModel.duration))
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
                    .onTapGesture {
                        toggleControls()
                    }
                
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
                                
                                targetVolume = newVolume
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
    }
    
    // MARK: - Seek Preview Overlay
    
    private func seekPreviewOverlay() -> some View {
        let targetTime = seekDragStartTime + seekDragOffset
        let clampedTarget = max(0, min(targetTime, viewModel.duration))
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
    
    // MARK: - Controls Overlay
    
    private func controlsOverlay() -> some View {
        VStack {
            // Top Bar
            HStack {
                Button(action: {
                    viewModel.resetOrientation()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    PrismIcon.close.image
                        .foregroundColor(.white)
                        .font(.title2)
                        .padding()
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Aspect Ratio Button
                Button(action: {
                    _ = settings.cycleAspectRatio()
                }) {
                    Image(systemName: settings.currentAspectRatio.iconName)
                        .foregroundColor(.white)
                        .font(.title2)
                        .padding()
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                
                // Subtitle Button
                Button(action: {
                    viewModel.toggleSubtitles()
                }) {
                    Image(systemName: viewModel.subtitlesEnabled ? "captions.bubble.fill" : "captions.bubble")
                        .foregroundColor(viewModel.subtitlesEnabled ? .purple : .white)
                        .font(.title2)
                        .padding()
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                
                Button(action: {
                    viewModel.toggleOrientation()
                }) {
                    PrismIcon.rotateScreen.image
                        .foregroundColor(.white)
                        .font(.title2)
                        .padding()
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
            }
            .padding(.top, 40)
            .padding(.horizontal)
            
            Spacer()
            
            // Center Controls: Skip Backward, Play/Pause, Skip Forward
            HStack(spacing: 50) {
                Button(action: {
                    viewModel.seekRelative(by: -settings.skipButtonSeconds)
                }) {
                    PrismIcon.seekBackward.image
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .shadow(radius: 5)
                }
                
                Button(action: {
                    viewModel.togglePlayPause()
                }) {
                    (viewModel.isPlaying ? PrismIcon.pause.image : PrismIcon.play.image)
                        .font(.system(size: 70))
                        .foregroundColor(.white)
                        .shadow(radius: 5)
                }
                
                Button(action: {
                    viewModel.seekRelative(by: settings.skipButtonSeconds)
                }) {
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
                    Text(formatTime(viewModel.currentTime))
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Slider(value: $viewModel.currentTime, in: 0...max(viewModel.duration, 1), onEditingChanged: { editing in
                        viewModel.isSeeking = editing
                        if !editing {
                            viewModel.seek(to: viewModel.currentTime)
                        }
                    })
                    .accentColor(.purple)
                    
                    Text(formatTime(viewModel.duration))
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding()
            }
            .background(
                LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
            )
        }
        .transition(.opacity)
    }
    
    // MARK: - Helper Methods
    
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
    
    func formatTime(_ time: Double) -> String {
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

// Helper for screen brightness allowing for future iOS versions
struct ScreenUtils {
    static var brightness: CGFloat {
        get {
            // Find the active window scene safely
            let scene = UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }
                .first
            return scene?.screen.brightness ?? 0.5 // Default if not found
        }
        set {
            let scene = UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }
                .first
            scene?.screen.brightness = newValue
        }
    }
}

struct VolumeView: UIViewRepresentable {
    @Binding var volume: Float

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.alpha = 0.001
        return view
    }
    
    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        DispatchQueue.main.async {
            if let slider = uiView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                slider.setValue(volume, animated: false)
            }
        }
    }
}

struct VideoPlayerController: UIViewControllerRepresentable {
    var player: AVPlayer
    var aspectRatio: AspectRatioOption
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false // We are using custom controls
        controller.videoGravity = aspectRatio.videoGravity
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.videoGravity = aspectRatio.videoGravity
    }
}

class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var showControls = true
    @Published var isSeeking = false
    @Published var subtitlesEnabled = false
    
    private var timeObserver: Any?
    private var controlTimer: Timer?
    private var availableSubtitleOptions: [AVMediaSelectionOption] = []
    
    func setupPlayer(with url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Disable automatic media selection to allow manual subtitle control
        player?.appliesMediaSelectionCriteriaAutomatically = false
        
        // Loop video
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
        
        Task {
            do {
                if let duration = try await playerItem.asset.load(.duration) as CMTime? {
                     DispatchQueue.main.async {
                         self.duration = CMTimeGetSeconds(duration)
                     }
                }
                
                // Load subtitle options
                await loadSubtitleOptions(from: playerItem)
            } catch {
                print("Failed to load duration: \(error)")
            }
        }
        
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self, !self.isSeeking else { return }
            self.currentTime = CMTimeGetSeconds(time)
            
            if self.duration == 0 || self.duration.isNaN { // refresh duration if needed
                if let currentItem = self.player?.currentItem {
                     self.duration = CMTimeGetSeconds(currentItem.duration)
                }
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
    
    private func loadSubtitleOptions(from playerItem: AVPlayerItem) async {
        do {
            let asset = playerItem.asset
            if let group = try await asset.loadMediaSelectionGroup(for: .legible) {
                DispatchQueue.main.async {
                    self.availableSubtitleOptions = group.options
                }
            }
        } catch {
            print("Failed to load subtitle options: \(error)")
        }
    }
    
    func toggleSubtitles() {
        guard let playerItem = player?.currentItem else { 
            print("No player item available for subtitle toggle")
            return 
        }
        
        Task { @MainActor in
            do {
                let asset = playerItem.asset
                guard let group = try await asset.loadMediaSelectionGroup(for: .legible) else {
                    print("No subtitle tracks available")
                    return
                }
                
                print("Available subtitle options: \(group.options.map { $0.displayName })")
                
                if self.subtitlesEnabled {
                    // Disable subtitles
                    playerItem.select(nil, in: group)
                    self.subtitlesEnabled = false
                    print("Subtitles disabled")
                } else if !group.options.isEmpty {
                    // Enable first available subtitle (prefer non-forced)
                    let preferredOption = group.options.first { !$0.hasMediaCharacteristic(.containsOnlyForcedSubtitles) } ?? group.options.first!
                    playerItem.select(preferredOption, in: group)
                    self.subtitlesEnabled = true
                    print("Subtitles enabled: \(preferredOption.displayName)")
                } else {
                    print("No subtitle options in group")
                }
            } catch {
                print("Failed to toggle subtitles: \(error)")
            }
        }
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
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
    
    func cleanup() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player?.pause()
        player = nil
        controlTimer?.invalidate()
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
