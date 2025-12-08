import SwiftUI

struct PrismBackground: View {
    var body: some View {
        ZStack {
            // Deep dark background
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            // Subtle ambient gradients (Orbs)
            GeometryReader { proxy in
                ZStack {
                    // Top Left Orb (Blue/Purple)
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "5B21B6").opacity(0.3), // Indigo
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 10,
                                endRadius: 300
                            )
                        )
                        .frame(width: 600, height: 600)
                        .offset(x: -200, y: -200)
                        .blur(radius: 60)
                    
                    // Bottom Right Orb (Deep Blue)
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "1E3A8A").opacity(0.2), // Dark Blue
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 10,
                                endRadius: 400
                            )
                        )
                        .frame(width: 700, height: 700)
                        .position(x: proxy.size.width + 100, y: proxy.size.height + 100)
                        .blur(radius: 80)
                }
            }
            .edgesIgnoringSafeArea(.all)
            
            // Glass overlay (noise/grain can be added here if we had assets, 
            // but for now we'll stick to a very subtle ultra-thin material overlay 
            // if we want the whole screen to feel "glassy", but usually 
            // the background is clear and content *on top* is glassy. 
            // The prompt says "background ... with glassmorphism look".
            // So we'll just keep the background clean and deep.)
        }
    }
}

// Helper for Hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    PrismBackground()
}
