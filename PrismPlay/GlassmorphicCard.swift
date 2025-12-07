import SwiftUI

struct GlassmorphicCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                ZStack {
                    Color.white.opacity(0.1)
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                }
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

// Reusing the VisualEffectBlur from HomeView (will move it here or keep shared)
//Ideally we should have a shared Utils file, but for now I'll define it here to be self-contained if needed,
//or I'll move the one from HomeView.swift to a common file.
//To minimize file creation, I will put VisualEffectBlur here as public.

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}
