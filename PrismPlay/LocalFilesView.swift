import SwiftUI

struct LocalFilesView: View {
    @State private var showFilePicker = false
    @State private var selectedVideo: VideoItem?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                // Background
                PrismBackground()
                
                VStack(spacing: 30) {
                    
                    Text("Local Files")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    Spacer()
                    
                    GlassmorphicCard {
                        VStack(spacing: 20) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            
                            Text("Browse & Import")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text("Select a video file from your device to play.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(40)
                    }
                    .onTapGesture {
                        showFilePicker = true
                    }
                    
                    Spacer()
                }
                .padding()
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

#Preview {
    LocalFilesView()
}
