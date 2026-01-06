import SwiftUI
import AVFoundation
import Combine

/// Centralized settings for the video player
/// All configurable values are stored here for future settings implementation
class PlayerSettings: ObservableObject {
    static let shared = PlayerSettings()
    
    // MARK: - Seek Settings
    
    /// Seconds to skip when using the skip buttons in controls
    @AppStorage("skipButtonSeconds") var skipButtonSeconds: Double = 10
    
    /// Seconds to seek when double-tapping left/right sides
    @AppStorage("doubleTapSeekSeconds") var doubleTapSeekSeconds: Double = 10
    
    /// Sensitivity for horizontal slide-to-seek (points of drag per second)
    @AppStorage("slideSeekSensitivity") var slideSeekSensitivity: Double = 2.0
    
    /// Seconds to seek on horizontal flick gesture
    @AppStorage("flickSeekSeconds") var flickSeekSeconds: Double = 10
    
    // MARK: - Gesture Settings
    
    /// Time window for detecting double-tap (in seconds)
    @AppStorage("doubleTapTimeThreshold") var doubleTapTimeThreshold: Double = 0.3
    
    /// Enable brightness gesture (left side swipe)
    @AppStorage("brightnessGestureEnabled") var brightnessGestureEnabled: Bool = true
    
    /// Enable volume gesture (right side swipe)
    @AppStorage("volumeGestureEnabled") var volumeGestureEnabled: Bool = true
    
    /// Enable horizontal swipe to seek
    @AppStorage("seekGestureEnabled") var seekGestureEnabled: Bool = true
    
    /// Enable double-tap to seek
    @AppStorage("doubleTapSeekEnabled") var doubleTapSeekEnabled: Bool = true
    
    /// Enable hold for 2x speed
    @AppStorage("holdFor2xSpeedEnabled") var holdFor2xSpeedEnabled: Bool = true
    
    // MARK: - Subtitle Settings
    
    /// Subtitle font size
    @AppStorage("subtitleSizeRaw") private var subtitleSizeRaw: String = SubtitleSize.medium.rawValue
    var subtitleSize: SubtitleSize {
        get { SubtitleSize(rawValue: subtitleSizeRaw) ?? .medium }
        set { subtitleSizeRaw = newValue.rawValue }
    }
    
    /// Subtitle background opacity (0.0 to 1.0)
    @AppStorage("subtitleBackgroundOpacity") var subtitleBackgroundOpacity: Double = 0.7
    
    /// Subtitle bottom margin in points
    @AppStorage("subtitleBottomMargin") var subtitleBottomMargin: Double = 20
    
    // MARK: - Playback Settings
    
    /// Auto-resume from last position
    @AppStorage("resumePlaybackAutomatically") var resumePlaybackAutomatically: Bool = true
    
    /// Default playback speed
    @AppStorage("defaultPlaybackSpeed") var defaultPlaybackSpeed: Double = 1.0
    
    /// Remember last used playback speed
    @AppStorage("rememberPlaybackSpeed") var rememberPlaybackSpeed: Bool = false
    
    /// Background audio playback
    @AppStorage("backgroundPlaybackEnabled") var backgroundPlaybackEnabled: Bool = false
    
    /// Picture-in-Picture enabled
    @AppStorage("pipEnabled") var pipEnabled: Bool = true
    
    /// Auto-rotate with device
    @AppStorage("autoRotateEnabled") var autoRotateEnabled: Bool = true
    
    // MARK: - Advanced Video Settings
    
    /// Hardware acceleration enabled
    @AppStorage("hardwareAccelerationEnabled") var hardwareAccelerationEnabled: Bool = true
    
    /// Decoder preference
    @AppStorage("decoderPreferenceRaw") private var decoderPreferenceRaw: String = DecoderPreference.auto.rawValue
    var decoderPreference: DecoderPreference {
        get { DecoderPreference(rawValue: decoderPreferenceRaw) ?? .auto }
        set { decoderPreferenceRaw = newValue.rawValue }
    }
    
    /// Buffer size preference
    @AppStorage("bufferSizeRaw") private var bufferSizeRaw: String = BufferSize.medium.rawValue
    var bufferSize: BufferSize {
        get { BufferSize(rawValue: bufferSizeRaw) ?? .medium }
        set { bufferSizeRaw = newValue.rawValue }
    }
    
    /// Skip silence in audio (useful for podcasts)
    @AppStorage("skipSilenceEnabled") var skipSilenceEnabled: Bool = false
    
    // MARK: - Aspect Ratio Settings
    
    /// Current aspect ratio index
    @Published var currentAspectRatioIndex: Int = 0
    
    /// Available aspect ratio options
    let aspectRatios: [AspectRatioOption] = AspectRatioOption.allCases
    
    /// Current aspect ratio
    var currentAspectRatio: AspectRatioOption {
        aspectRatios[currentAspectRatioIndex]
    }
    
    /// Cycle to the next aspect ratio
    func cycleAspectRatio() -> AspectRatioOption {
        currentAspectRatioIndex = (currentAspectRatioIndex + 1) % aspectRatios.count
        return currentAspectRatio
    }
    
    // MARK: - Control Timing
    
    /// Seconds before controls auto-hide
    @AppStorage("controlsAutoHideDelay") var controlsAutoHideDelay: Double = 4.0
    
    /// Duration to show seek feedback overlay
    @AppStorage("seekFeedbackDuration") var seekFeedbackDuration: Double = 1.5
    
    private init() {}
    
    // MARK: - Reset Methods
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        skipButtonSeconds = 10
        doubleTapSeekSeconds = 10
        slideSeekSensitivity = 2.0
        flickSeekSeconds = 10
        doubleTapTimeThreshold = 0.3
        brightnessGestureEnabled = true
        volumeGestureEnabled = true
        seekGestureEnabled = true
        doubleTapSeekEnabled = true
        holdFor2xSpeedEnabled = true
        subtitleSizeRaw = SubtitleSize.medium.rawValue
        subtitleBackgroundOpacity = 0.7
        subtitleBottomMargin = 20
        resumePlaybackAutomatically = true
        defaultPlaybackSpeed = 1.0
        rememberPlaybackSpeed = false
        backgroundPlaybackEnabled = false
        pipEnabled = true
        autoRotateEnabled = true
        hardwareAccelerationEnabled = true
        decoderPreferenceRaw = DecoderPreference.auto.rawValue
        bufferSizeRaw = BufferSize.medium.rawValue
        skipSilenceEnabled = false
        controlsAutoHideDelay = 4.0
        seekFeedbackDuration = 1.5
    }
}

// MARK: - Aspect Ratio Option

enum AspectRatioOption: String, CaseIterable {
    case fit = "Fit"
    case fill = "Fill"
    case stretch = "Stretch"
    case sixteenNine = "16:9"
    case fourThree = "4:3"
    
    /// Display name for the UI
    var displayName: String {
        return rawValue
    }
    
    /// The AVLayerVideoGravity value for this option
    var videoGravity: AVLayerVideoGravity {
        switch self {
        case .fit:
            return .resizeAspect
        case .fill:
            return .resizeAspectFill
        case .stretch:
            return .resize
        case .sixteenNine, .fourThree:
            // These use custom aspect ratio masks, but default to fit
            return .resizeAspect
        }
    }
    
    /// Icon name for the aspect ratio button
    var iconName: String {
        switch self {
        case .fit:
            return "rectangle.arrowtriangle.2.inward"
        case .fill:
            return "rectangle.arrowtriangle.2.outward"
        case .stretch:
            return "arrow.left.and.right.square"
        case .sixteenNine:
            return "rectangle.ratio.16.to.9"
        case .fourThree:
            return "rectangle.ratio.4.to.3"
        }
    }
    
    /// The aspect ratio value (width / height) for custom ratios
    var aspectRatioValue: CGFloat? {
        switch self {
        case .sixteenNine:
            return 16.0 / 9.0
        case .fourThree:
            return 4.0 / 3.0
        default:
            return nil
        }
    }
}
