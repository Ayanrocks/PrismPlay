import SwiftUI
import AVFoundation
import Combine

/// Centralized settings for the video player
/// All configurable values are stored here for future settings implementation
class PlayerSettings: ObservableObject {
    static let shared = PlayerSettings()
    
    // MARK: - Seek Settings
    
    /// Seconds to skip when using the skip buttons in controls
    @Published var skipButtonSeconds: Double = 10
    
    /// Seconds to seek when double-tapping left/right sides
    @Published var doubleTapSeekSeconds: Double = 10
    
    /// Sensitivity for horizontal slide-to-seek (points of drag per second)
    @Published var slideSeekSensitivity: Double = 2.0
    
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
    @Published var controlsAutoHideDelay: Double = 4.0
    
    /// Duration to show seek feedback overlay
    @Published var seekFeedbackDuration: Double = 1.5
    
    private init() {}
}

// MARK: - Aspect Ratio Option

enum AspectRatioOption: String, CaseIterable {
    case fit = "Fit"
    case fill = "Fill"
    case stretch = "Stretch"
    case sixteenNine = "16:9"
    case fourThree = "4:3"
    
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
