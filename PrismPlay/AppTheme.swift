import SwiftUI

struct AppTheme {
    static let backgroundColor = Color.black
    static let glassEffect = UIBlurEffect.Style.systemUltraThinMaterialDark
    
    // Gradient definitions if we want reuse
    static let primaryGradient = LinearGradient(
        gradient: Gradient(colors: [Color.purple, Color.blue]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
