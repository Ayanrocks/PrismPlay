import SwiftUI


struct VideoItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct HomeView: View {
    @State private var showJellyfinLogin = false
    @State private var hasJellyfinCredentials = false // Placeholder for actual check
    @State private var showFilePicker = false
    @State private var selectedVideo: VideoItem?

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 40) {
                    Text("PrismPlay")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                    
                    HStack(spacing: 30) {
                        // Local Files Option
                        Button(action: {
                            showFilePicker = true
                        }) {
                            OptionCard(title: "Local Files", iconName: "folder.fill", color: .blue)
                        }
                        
                        // Jellyfin Option
                        Button(action: {
                            if hasJellyfinCredentials {
                                // Navigate to Jellyfin library
                                print("Navigate to Jellyfin")
                            } else {
                                showJellyfinLogin = true
                            }
                        }) {
                            OptionCard(title: "Jellyfin", iconName: "tv.fill", color: .purple)
                        }
                    }
                    .padding()
                }
            }
            .sheet(isPresented: $showJellyfinLogin) {
                JellyfinLoginView(isPresented: $showJellyfinLogin)
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker { url in
                    print("Selected file: \(url)")
                    selectedVideo = VideoItem(url: url)
                }
            }
            .fullScreenCover(item: $selectedVideo) { video in
                VideoPlayerView(url: video.url)
            }
        }
    }
}

struct OptionCard: View {
    let title: String
    let iconName: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.white)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 10)
        }
        .frame(width: 160, height: 200)
        .background(
            ZStack {
                color.opacity(0.6)
                
                // Glassmorphism effect
                VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
            }
        )
        .cornerRadius(20)
        .shadow(color: color.opacity(0.4), radius: 10, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

// Helper for Glassmorphism
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

#Preview {
    HomeView()
}
