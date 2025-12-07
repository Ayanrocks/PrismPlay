import SwiftUI
import AVKit
import Combine
import UIKit
import MediaPlayer

struct VideoPlayerView: View {
    let url: URL
    @StateObject private var viewModel = PlayerViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    // Gesture States
    @State private var dragStartBrightness: CGFloat = 0
    @State private var dragStartVolume: Float = 0
    @State private var isDraggingBrightness = false
    @State private var isDraggingVolume = false
    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    
    // Volume Control
    @State private var targetVolume: Float = AVAudioSession.sharedInstance().outputVolume
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if let player = viewModel.player {
                VideoPlayerController(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        GeometryReader { geometry in
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
                                    .onTapGesture {
                                        toggleControls()
                                    }
                                
                                // Center: Tap Only
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        toggleControls()
                                    }
                                
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
                                                
                                                targetVolume = newVolume
                                                showFeedback(text: "Volume: \(Int(newVolume * 100))%")
                                            }
                                            .onEnded { _ in
                                                isDraggingVolume = false
                                                dragStartVolume = 0
                                                hideFeedback()
                                            }
                                    )
                                    .onTapGesture {
                                        toggleControls()
                                    }
                            }
                        }
                    )
                
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
                    VStack {
                        // Top Bar
                        HStack {
                            Button(action: {
                                viewModel.resetOrientation()
                                // Delay dismissal slightly to allow rotation to begin
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
                                viewModel.seekRelative(by: -5)
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
                                viewModel.seekRelative(by: 5)
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
                                
                                Slider(value: $viewModel.currentTime, in: 0...viewModel.duration, onEditingChanged: { editing in
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
    
    func formatTime(_ time: Double) -> String {
        let seconds = Int(time) % 60
        let minutes = Int(time) / 60
        return String(format: "%02d:%02d", minutes, seconds)
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
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false // We are using custom controls
        controller.videoGravity = .resizeAspect
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var showControls = true
    @Published var isSeeking = false
    
    private var timeObserver: Any?
    private var controlTimer: Timer?
    
    func setupPlayer(with url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
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
            let newTime = currentTime + seconds
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
