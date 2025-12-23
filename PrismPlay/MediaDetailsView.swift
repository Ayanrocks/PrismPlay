import SwiftUI

struct MediaDetailsView: View {
    let item: JellyfinItem
    @ObservedObject var jellyfinService = JellyfinService.shared
    @State private var detailedItem: JellyfinItem?
    @State private var seasons: [JellyfinItem] = []
    @State private var episodes: [JellyfinItem] = []
    @State private var selectedSeasonId: String?
    @State private var isLoadingDetails = true
    @State private var playingItem: JellyfinItem?
    @Environment(\.presentationMode) var presentationMode
    
    // Computed props
    var directors: [JellyfinPerson] {
        detailedItem?.People?.filter { $0.PersonType == "Director" } ?? []
    }
    
    var writers: [JellyfinPerson] {
        detailedItem?.People?.filter { $0.PersonType == "Writer" } ?? []
    }
    
    var technicalInfo: (fps: Float?, filename: String?) {
        guard let sources = detailedItem?.MediaSources?.first else { return (nil, nil) }
        let filename = sources.Name ?? sources.Path?.components(separatedBy: "/").last
        let fps = sources.MediaStreams?.first(where: { $0.StreamType == "Video" })?.AverageFrameRate
        return (fps, filename)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // ... (backgrounds remain same)
                PrismBackground()
                
                // Background Image Logic (same)
                if let itemId = detailedItem?.Id ?? Optional(item.Id),
                   let backdropUrl = jellyfinService.imageURL(for: itemId, imageTag: detailedItem?.backdropImageTag, type: "Backdrop") {
                     // ... (AsyncImage content same)
                     AsyncImage(url: backdropUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height * 0.6)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .black.opacity(0.0), location: 0.0),
                                        .init(color: .black.opacity(0.4), location: 0.4),
                                        .init(color: .black, location: 0.95)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.3))
                    }
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.3)
                    .edgesIgnoringSafeArea(.top)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Spacer()
                            .frame(height: geometry.size.height * 0.35)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(detailedItem?.Name ?? item.Name)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(radius: 5)
                            
                            // Validated Metadata Line (Year, Rating, Duration)
                            HStack(spacing: 12) {
                                if let year = detailedItem?.ProductionYear {
                                    Text("\(String(year))")
                                        .foregroundColor(.gray)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                
                                if let rating = detailedItem?.OfficialRating {
                                    Text(rating)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.gray.opacity(0.4))
                                        .cornerRadius(4)
                                        .foregroundColor(.white)
                                }
                                
                                if let runtime = detailedItem?.RunTimeTicks {
                                    let _ = runtime / 10_000_000 / 60
                                }
                            }
                            
                            // Overview
                            if let overview = detailedItem?.Overview {
                                Text(overview)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 8)
                            }
                            
                            if detailedItem?.ItemType == "Series" {
                                // TV Show Specific UI
                                
                                // Season Selector
                                if !seasons.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 15) {
                                            ForEach(seasons) { season in
                                                Button(action: {
                                                    selectedSeasonId = season.Id
                                                    loadEpisodes(seriesId: item.Id, seasonId: season.Id)
                                                }) {
                                                    Text(season.Name)
                                                        .font(.subheadline)
                                                        .fontWeight(selectedSeasonId == season.Id ? .bold : .regular)
                                                        .padding(.horizontal, 16)
                                                        .padding(.vertical, 8)
                                                        .background(selectedSeasonId == season.Id ? .white.opacity(0.2) : .clear)
                                                        .cornerRadius(20)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 20)
                                                                .stroke(selectedSeasonId == season.Id ? Color.white : Color.gray, lineWidth: 1)
                                                        )
                                                        .foregroundColor(selectedSeasonId == season.Id ? .white : .gray)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 5)
                                    }
                                }
                                
                                // Episode List
                                if !episodes.isEmpty {
                                    VStack(alignment: .leading, spacing: 15) {
                                        ForEach(episodes) { episode in
                                            HStack {
                                                Button(action: {
                                                    playingItem = episode
                                                }) {
                                                    ZStack {
                                                        AsyncImage(url: jellyfinService.imageURL(for: episode.Id, imageTag: episode.primaryImageTag)) { image in
                                                            image.resizable().aspectRatio(contentMode: .fill)
                                                        } placeholder: {
                                                            Rectangle().fill(Color.gray.opacity(0.3))
                                                        }
                                                        .frame(width: 80, height: 45)
                                                        .cornerRadius(4)
                                                        .playbackProgressOverlay(for: episode, showRemainingTime: false)
                                                        
                                                        PlayButtonOverlay(item: episode, size: 28)
                                                    }
                                                }
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("\(episode.IndexNumber ?? 0). \(episode.Name)")
                                                        .font(.subheadline)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.white)
                                                        .lineLimit(nil)
                                                    
                                                    if let ticks = episode.RunTimeTicks {
                                                         Text("\(ticks / 10000000 / 60)m")
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    }
                                                    
                                                    if let overview = episode.Overview, !overview.isEmpty {
                                                        Text(overview)
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                            .lineLimit(3)
                                                            .padding(.top, 2)
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                Button(action: {
                                                    // Download Episode
                                                }) {
                                                    Image(systemName: "arrow.down.to.line")
                                                        .foregroundColor(.white.opacity(0.7))
                                                        .padding(8)
                                                        .background(Color.white.opacity(0.1))
                                                        .clipShape(Circle())
                                                }
                                            }
                                            .padding(.vertical, 4)
                                            
                                            Divider().background(Color.gray.opacity(0.2))
                                        }
                                    }
                                    .padding(.top, 10)
                                }
                                
                            } else {
                                // Movie / Standard UI
                                
                                // Action Buttons (Play)
                                Button(action: {
                                    playingItem = detailedItem ?? item
                                }) {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        if let remaining = (detailedItem ?? item).remainingTimeString {
                                            Text("Resume • \(remaining)")
                                                .fontWeight(.bold)
                                        } else {
                                            Text("Play")
                                                .fontWeight(.bold)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .padding(.top, 8)
                                
                                // Secondary Actions Row (Download / Watched)
                                HStack(spacing: 40) {
                                    Button(action: {
                                        // Download action
                                    }) {
                                        VStack(spacing: 5) {
                                            Image(systemName: "arrow.down.to.line")
                                                .font(.system(size: 26))
                                            Text("Download")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.white.opacity(0.9))
                                    }
                                    
                                    Button(action: {
                                        // Mark as watched action
                                    }) {
                                        VStack(spacing: 5) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 26))
                                            Text("Watched")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.white.opacity(0.9))
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.top, 10)
                            }
                            

                            
                            // Crew Section (Common)
                            if !directors.isEmpty || !writers.isEmpty {
                                HStack(alignment: .top, spacing: 30) {
                                    if !directors.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Director")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            ForEach(directors) { person in
                                                Text(person.Name)
                                                    .font(.subheadline)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                    
                                    if !writers.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Writer")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            ForEach(writers) { person in
                                                Text(person.Name)
                                                    .font(.subheadline)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 10)
                            }
                            
                            // Cast Section (Common)
                            if let people = detailedItem?.People, !people.isEmpty {
                                Text("Cast")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.top, 16)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(people) { person in
                                            NavigationLink(destination: PersonDetailsView(personName: person.Name, personId: person.Id, personImageTag: person.PrimaryImageTag)) {
                                                VStack {
                                                    AsyncImage(url: jellyfinService.imageURL(for: person.Id, imageTag: person.PrimaryImageTag, type: "Primary")) { image in
                                                        image
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                    } placeholder: {
                                                        Circle()
                                                            .fill(Color.gray.opacity(0.3))
                                                            .overlay(Text(person.Name.prefix(1)).foregroundColor(.white))
                                                    }
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(Circle())
                                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                                    
                                                    Text(person.Name)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                        .multilineTextAlignment(.center)
                                                        .lineLimit(2)
                                                        .frame(width: 80)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Genres (Common)
                            VStack(alignment: .leading, spacing: 5) {
                                if let genres = detailedItem?.Genres, !genres.isEmpty {
                                    HStack(alignment: .top) {
                                        Text("Genres:")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack {
                                                ForEach(genres, id: \.self) { genre in
                                                    NavigationLink(destination: GenreDetailsView(genre: genre)) {
                                                        Text(genre)
                                                            .font(.caption)
                                                            .padding(.horizontal, 10)
                                                            .padding(.vertical, 5)
                                                            .background(.ultraThinMaterial)
                                                            .cornerRadius(10)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 10)
                                                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                                            )
                                                            .foregroundColor(.white)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.top, 10)

                            // Technical Details (Only show for movies or if relevant)
                            // Usually Technical info is for file, which Series container doesn't have linearly.
                            if detailedItem?.ItemType != "Series" {
                                let info = technicalInfo
                                if info.fps != nil || info.filename != nil {
                                    Divider()
                                        .background(Color.gray.opacity(0.3))
                                        .padding(.vertical, 10)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Technical Details")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        if let filename = info.filename {
                                            HStack(alignment: .top) {
                                                Text("File:")
                                                    .foregroundColor(.gray)
                                                    .font(.caption)
                                                Text(filename)
                                                    .foregroundColor(.white.opacity(0.8))
                                                    .font(.caption)
                                                    .lineLimit(nil)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                        
                                        if let fps = info.fps {
                                            HStack {
                                                Text("FPS:")
                                                    .foregroundColor(.gray)
                                                    .font(.caption)
                                                Text(String(format: "%.2f", fps))
                                                    .foregroundColor(.white.opacity(0.8))
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 50)
                    }
                }
            }
            .navigationBarHidden(false)
            .edgesIgnoringSafeArea(.top)
            .fullScreenCover(item: $playingItem) { item in
                JellyfinPlayerView(item: item)
            }
        }
        .onAppear {
            loadDetails()
        }
    }
    
    private func loadDetails() {
        jellyfinService.getItemDetails(itemId: item.Id) { fetchedItem in
            Task { @MainActor in
                if let fetchedItem = fetchedItem {
                    self.detailedItem = fetchedItem
                    
                    if fetchedItem.ItemType == "Series" {
                        loadSeasons(seriesId: fetchedItem.Id)
                    }
                } else {
                    // Fallback or error handling
                }
                self.isLoadingDetails = false
            }
        }
    }
    
    private func loadSeasons(seriesId: String) {
        jellyfinService.fetchSeasons(seriesId: seriesId) { fetchedSeasons in
            Task { @MainActor in
                self.seasons = fetchedSeasons ?? []
                // Default to first season
                if let firstSeason = self.seasons.first {
                    self.selectedSeasonId = firstSeason.Id
                    loadEpisodes(seriesId: seriesId, seasonId: firstSeason.Id)
                }
            }
        }
    }
    
    private func loadEpisodes(seriesId: String, seasonId: String) {
        jellyfinService.fetchEpisodes(seriesId: seriesId, seasonId: seasonId) { fetchedEpisodes in
            Task { @MainActor in
                self.episodes = fetchedEpisodes ?? []
            }
        }
    }
}
