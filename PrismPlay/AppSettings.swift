import SwiftUI
import Combine

/// App-wide settings for appearance and general configuration
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // MARK: - Appearance
    
    /// Current color scheme preference (raw storage)
    @AppStorage("colorSchemeRaw") private var colorSchemeRaw: String = AppColorScheme.dark.rawValue
    
    var colorScheme: AppColorScheme {
        get { AppColorScheme(rawValue: colorSchemeRaw) ?? .dark }
        set { 
            colorSchemeRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    /// Whether to follow system theme
    @AppStorage("useSystemTheme") var useSystemTheme: Bool = false {
        willSet { objectWillChange.send() }
    }
    
    // MARK: - App Info (Read-only)
    
    /// App version string
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// Build number
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    /// Full version string for display
    var fullVersionString: String {
        "Version \(appVersion) (\(buildNumber))"
    }
    
    private init() {}
}

// MARK: - Color Scheme

enum AppColorScheme: String, CaseIterable {
    case dark = "Dark"
    case light = "Light"
    
    var displayName: String {
        return rawValue
    }
    
    var colorScheme: ColorScheme {
        switch self {
        case .dark: return .dark
        case .light: return .light
        }
    }
    
    var iconName: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }
}

// MARK: - Subtitle Size

enum SubtitleSize: String, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "Extra Large"
    
    var fontSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 18
        case .large: return 22
        case .extraLarge: return 28
        }
    }
    
    var displayName: String {
        return rawValue
    }
}

// MARK: - Decoder Preference

enum DecoderPreference: String, CaseIterable {
    case auto = "Auto"
    case software = "Software"
    case hardware = "Hardware"
    
    var displayName: String {
        return rawValue
    }
    
    var description: String {
        switch self {
        case .auto: return "System decides best option"
        case .software: return "CPU-based decoding"
        case .hardware: return "GPU-accelerated decoding"
        }
    }
}

// MARK: - Buffer Size

enum BufferSize: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case veryHigh = "Very High"
    
    var displayName: String {
        return rawValue
    }
    
    var description: String {
        switch self {
        case .low: return "5 MB - Faster start, more buffering"
        case .medium: return "15 MB - Balanced"
        case .high: return "30 MB - Smoother playback"
        case .veryHigh: return "50 MB - Best for unstable connections"
        }
    }
    
    var sizeInBytes: Int {
        switch self {
        case .low: return 5 * 1024 * 1024
        case .medium: return 15 * 1024 * 1024
        case .high: return 30 * 1024 * 1024
        case .veryHigh: return 50 * 1024 * 1024
        }
    }
}
