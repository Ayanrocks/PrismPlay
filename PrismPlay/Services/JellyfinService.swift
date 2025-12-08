import Foundation
import Combine
import SwiftUI

@MainActor
class JellyfinService: ObservableObject {
    static let shared = JellyfinService()
    
    @Published var isAuthenticated = false
    @Published var serverURL: String = ""
    @Published var userId: String = ""
    @Published var accessToken: String = ""
    
    @Published var savedServers: [JellyfinServerConfig] = []
    
    private let serversKey = "saved_jellyfin_servers"
    
    private init() {
        loadServers()
    }
    
    private func loadServers() {
        if let data = UserDefaults.standard.data(forKey: serversKey),
           let servers = try? JSONDecoder().decode([JellyfinServerConfig].self, from: data) {
            self.savedServers = servers
            
            // Auto-connect to the first one if available (optional, but good UX)
            // For now, let's just leave it to user selection or restore last session
        }
    }
    
    private func saveServers() {
        if let data = try? JSONEncoder().encode(savedServers) {
            UserDefaults.standard.set(data, forKey: serversKey)
        }
    }
    
    func addServer(url: String, username: String, userId: String, accessToken: String) {
        let newServer = JellyfinServerConfig(name: username, url: url, username: username, accessToken: accessToken, userId: userId)
        if !savedServers.contains(where: { $0.url == url && $0.userId == userId }) {
            savedServers.append(newServer)
            saveServers()
        }
    }
    
    func removeServer(at offsets: IndexSet) {
        savedServers.remove(atOffsets: offsets)
        saveServers()
    }
    
    func selectServer(_ server: JellyfinServerConfig) {
        self.serverURL = server.url
        self.userId = server.userId
        self.accessToken = server.accessToken
        self.isAuthenticated = true
    }
    
    func authenticate(server: String, username: String, password: String, completion: @escaping @Sendable (Result<Bool, Error>) -> Void) {
        guard let url = URL(string: "\(server)/Users/AuthenticateByName") else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Authorization header format for Jellyfin: MediaBrowser Client="ClientName", Device="DeviceName", DeviceId="DeviceId", Version="ClientVersion"
        let authHeader = "MediaBrowser Client=\"PrismPlay\", Device=\"iOS\", DeviceId=\"\(UUID().uuidString)\", Version=\"1.0.0\""
        request.addValue(authHeader, forHTTPHeaderField: "X-Emby-Authorization")
        
        let body: [String: String] = [
            "Username": username,
            "Pw": password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "No data", code: 0, userInfo: nil)))
                }
                return
            }
            
            DispatchQueue.main.async {
                do {
                    let authResponse = try JellyfinDecoder.decode(JellyfinAuthResponse.self, from: data)
                    self?.serverURL = server
                    self?.userId = authResponse.User.Id
                    self?.accessToken = authResponse.AccessToken
                    self?.isAuthenticated = true
                    
                    // Save the successful login
                    self?.addServer(url: server, username: username, userId: authResponse.User.Id, accessToken: authResponse.AccessToken)
                    
                    completion(.success(true))
                } catch {
                    // Try to decode error string if possible, or just print data
                    print("Decoding error: \(error)")
                    if let str = String(data: data, encoding: .utf8) {
                        print("Response body: \(str)")
                    }
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func fetchMediaItems(completion: @escaping @Sendable ([JellyfinItem]?) -> Void) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion(nil)
            return
        }
        
        // Endpoint to get items (movies/shows) from user's view
        // Using /Users/{UserId}/Items with Recursive=true to get everything or just top level
        // Let's try getting recent items or just root library items first. 
        // A better query for "movies and shows" might be /Users/{UserId}/Items?Recursive=true&IncludeItemTypes=Movie,Series
        
        let urlString = "\(serverURL)/Users/\(userId)/Items?Recursive=true&IncludeItemTypes=Movie,Series&Fields=PrimaryImageAspectRatio,SortName,DateCreated,UserData,RunTimeTicks"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("MediaBrowser Client=\"PrismPlay\", Device=\"iOS\", DeviceId=\"\(UUID().uuidString)\", Version=\"1.0.0\", Token=\"\(accessToken)\"", forHTTPHeaderField: "X-Emby-Authorization")

        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching items: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            DispatchQueue.main.async {
                do {
                    let itemsResponse = try JellyfinDecoder.decode(JellyfinItemsResponse.self, from: data)
                    completion(itemsResponse.Items)
                } catch {
                    print("Error decoding items: \(error)")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    func getItemDetails(itemId: String, completion: @escaping @Sendable (JellyfinItem?) -> Void) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion(nil)
            return
        }
        
        // Fetch details including People, Overview, Genres, etc.
        let urlString = "\(serverURL)/Users/\(userId)/Items/\(itemId)?Fields=People,Overview,Genres,RunTimeTicks,ProductionYear,CommunityRating,OfficialRating,PrimaryImageAspectRatio,DateCreated,MediaSources,BackdropImageTags,UserData"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("MediaBrowser Client=\"PrismPlay\", Device=\"iOS\", DeviceId=\"\(UUID().uuidString)\", Version=\"1.0.0\", Token=\"\(accessToken)\"", forHTTPHeaderField: "X-Emby-Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching item details: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            DispatchQueue.main.async {
                do {
                    let item = try JellyfinDecoder.decode(JellyfinItem.self, from: data)
                    completion(item)
                } catch {
                    print("Error decoding item details: \(error)")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    func imageURL(for itemId: String, imageTag: String?, type: String = "Primary") -> URL? {
        guard !serverURL.isEmpty else { return nil }
        
        var urlString = ""
        if type == "Backdrop" {
             urlString = "\(serverURL)/Items/\(itemId)/Images/Backdrop/0"
        } else {
             urlString = "\(serverURL)/Items/\(itemId)/Images/\(type)"
        }
        
        if let tag = imageTag {
            urlString += "?tag=\(tag)"
        }
        return URL(string: urlString)
    }
    
    func fetchLibraries(completion: @escaping @Sendable ([JellyfinLibrary]?) -> Void) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion(nil)
            return
        }
        
        let urlString = "\(serverURL)/Users/\(userId)/Views"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("MediaBrowser Client=\"PrismPlay\", Device=\"iOS\", DeviceId=\"\(UUID().uuidString)\", Version=\"1.0.0\", Token=\"\(accessToken)\"", forHTTPHeaderField: "X-Emby-Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching libraries: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            DispatchQueue.main.async {
                do {
                    let librariesResponse = try JellyfinDecoder.decode(JellyfinLibrariesResponse.self, from: data)
                    completion(librariesResponse.Items)
                } catch {
                    print("Error decoding libraries: \(error)")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    func fetchLibraryItems(libraryId: String, limit: Int = 10, completion: @escaping @Sendable ([JellyfinItem]?) -> Void) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion(nil)
            return
        }
        
        let urlString = "\(serverURL)/Users/\(userId)/Items?ParentId=\(libraryId)&Limit=\(limit)&Fields=PrimaryImageAspectRatio,SortName,DateCreated,UserData,RunTimeTicks&SortBy=DateCreated&SortOrder=Descending"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("MediaBrowser Client=\"PrismPlay\", Device=\"iOS\", DeviceId=\"\(UUID().uuidString)\", Version=\"1.0.0\", Token=\"\(accessToken)\"", forHTTPHeaderField: "X-Emby-Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching library items: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            DispatchQueue.main.async {
                do {
                    let itemsResponse = try JellyfinDecoder.decode(JellyfinItemsResponse.self, from: data)
                    completion(itemsResponse.Items)
                } catch {
                    print("Error decoding library items: \(error)")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    func fetchLibraryItemsPaginated(
        libraryId: String,
        startIndex: Int = 0,
        limit: Int = 30,
        sortBy: String = "DateCreated",
        sortOrder: String = "Descending",
        completion: @escaping @Sendable ([JellyfinItem]?) -> Void
    ) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion(nil)
            return
        }
        
        let urlString = "\(serverURL)/Users/\(userId)/Items?ParentId=\(libraryId)&StartIndex=\(startIndex)&Limit=\(limit)&Fields=PrimaryImageAspectRatio,SortName,DateCreated,UserData,RunTimeTicks&SortBy=\(sortBy)&SortOrder=\(sortOrder)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("MediaBrowser Client=\"PrismPlay\", Device=\"iOS\", DeviceId=\"\(UUID().uuidString)\", Version=\"1.0.0\", Token=\"\(accessToken)\"", forHTTPHeaderField: "X-Emby-Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching library items: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            DispatchQueue.main.async {
                do {
                    let itemsResponse = try JellyfinDecoder.decode(JellyfinItemsResponse.self, from: data)
                    completion(itemsResponse.Items)
                } catch {
                    print("Error decoding library items: \(error)")
                    completion(nil)
                }
            }
        }.resume()
    }
    func fetchItems(byPersonId personId: String, limit: Int = 50, completion: @escaping @Sendable ([JellyfinItem]?) -> Void) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion(nil)
            return
        }
        
        let urlString = "\(serverURL)/Users/\(userId)/Items?PersonIds=\(personId)&Limit=\(limit)&Recursive=true&IncludeItemTypes=Movie,Series&Fields=PrimaryImageAspectRatio,SortName,DateCreated,ProductionYear&SortBy=DateCreated&SortOrder=Descending"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        performRequest(url: url, completion: completion)
    }
    
    func fetchItems(byGenre genre: String, limit: Int = 50, completion: @escaping @Sendable ([JellyfinItem]?) -> Void) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion(nil)
            return
        }
        
        // Genre might need to be URL encoded
        guard let encodedGenre = genre.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(nil)
            return
        }
        
        let urlString = "\(serverURL)/Users/\(userId)/Items?Genres=\(encodedGenre)&Limit=\(limit)&Recursive=true&IncludeItemTypes=Movie,Series&Fields=PrimaryImageAspectRatio,SortName,DateCreated,ProductionYear&SortBy=DateCreated&SortOrder=Descending"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        performRequest(url: url, completion: completion)
    }
    
    func fetchSeasons(seriesId: String, completion: @escaping @Sendable ([JellyfinItem]?) -> Void) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion(nil)
            return
        }
        
        let urlString = "\(serverURL)/Users/\(userId)/Items?ParentId=\(seriesId)&IncludeItemTypes=Season&SortBy=SortName"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        performRequest(url: url, completion: completion)
    }
    
    func fetchEpisodes(seriesId: String, seasonId: String, completion: @escaping @Sendable ([JellyfinItem]?) -> Void) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion(nil)
            return
        }
        
        // Fetch episodes for a specific season
        let urlString = "\(serverURL)/Users/\(userId)/Items?ParentId=\(seasonId)&IncludeItemTypes=Episode&SortBy=SortName,IndexNumber&Fields=PrimaryImageAspectRatio,Overview,IndexNumber,ParentIndexNumber,MediaSources,RunTimeTicks"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        performRequest(url: url, completion: completion)
    }

    private func performRequest(url: URL, completion: @escaping @Sendable ([JellyfinItem]?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("MediaBrowser Client=\"PrismPlay\", Device=\"iOS\", DeviceId=\"\(UUID().uuidString)\", Version=\"1.0.0\", Token=\"\(accessToken)\"", forHTTPHeaderField: "X-Emby-Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching items: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            DispatchQueue.main.async {
                do {
                    let itemsResponse = try JellyfinDecoder.decode(JellyfinItemsResponse.self, from: data)
                    completion(itemsResponse.Items)
                } catch {
                    print("Error decoding items: \(error)")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    // MARK: - Streaming URL
    
    /// Constructs a streaming URL using HLS transcoding for universal iOS compatibility
    /// Server handles transcoding to H.264/AAC which AVPlayer can handle
    func getStreamURL(itemId: String) -> URL? {
        guard !serverURL.isEmpty, !accessToken.isEmpty, !userId.isEmpty else { return nil }
        
        // HLS master playlist - Jellyfin transcodes to iOS-compatible format
        let urlString = "\(serverURL)/Videos/\(itemId)/master.m3u8?UserId=\(userId)&api_key=\(accessToken)&MediaSourceId=\(itemId)&VideoCodec=h264&AudioCodec=aac&MaxAudioChannels=2&SegmentContainer=ts&MinSegments=1&BreakOnNonKeyFrames=true"
        return URL(string: urlString)
    }
    
    /// Constructs a direct stream URL (only for iOS-native formats like MP4/H.264)
    func getDirectStreamURL(itemId: String) -> URL? {
        guard !serverURL.isEmpty, !accessToken.isEmpty else { return nil }
        
        let urlString = "\(serverURL)/Videos/\(itemId)/stream?static=true&api_key=\(accessToken)"
        return URL(string: urlString)
    }
    
    // MARK: - Subtitles
    
    /// Get available subtitle streams from a JellyfinItem's MediaSources
    func getSubtitleStreams(from item: JellyfinItem) -> [MediaStream] {
        guard let mediaSource = item.MediaSources?.first,
              let streams = mediaSource.MediaStreams else {
            return []
        }
        
        return streams.filter { $0.StreamType == "Subtitle" }
    }
    
    /// Constructs a subtitle URL for a given media item and subtitle stream
    /// Format: WebVTT for best iOS compatibility
    func getSubtitleURL(itemId: String, mediaSourceId: String? = nil, subtitleIndex: Int) -> URL? {
        guard !serverURL.isEmpty, !accessToken.isEmpty else { return nil }
        
        let sourceId = mediaSourceId ?? itemId
        // Request WebVTT format which AVPlayer can handle via AVMediaSelectionOption
        let urlString = "\(serverURL)/Videos/\(itemId)/\(sourceId)/Subtitles/\(subtitleIndex)/Stream.vtt?api_key=\(accessToken)"
        return URL(string: urlString)
    }
    
    /// Constructs a subtitle URL in SRT format (for download/external use)
    func getSubtitleSRTURL(itemId: String, mediaSourceId: String? = nil, subtitleIndex: Int) -> URL? {
        guard !serverURL.isEmpty, !accessToken.isEmpty else { return nil }
        
        let sourceId = mediaSourceId ?? itemId
        let urlString = "\(serverURL)/Videos/\(itemId)/\(sourceId)/Subtitles/\(subtitleIndex)/Stream.srt?api_key=\(accessToken)"
        return URL(string: urlString)
    }
    
    // MARK: - Resume / Continue Watching
    
    /// Fetches items that the user has partially watched (Continue Watching)
    func fetchResumeItems(limit: Int = 12, completion: @escaping @Sendable ([JellyfinItem]?) -> Void) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion(nil)
            return
        }
        
        let urlString = "\(serverURL)/Users/\(userId)/Items/Resume?Limit=\(limit)&Fields=PrimaryImageAspectRatio,Overview,MediaSources,RunTimeTicks,UserData,SeriesName,SeriesId&EnableImageTypes=Primary,Backdrop,Thumb"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        performRequest(url: url, completion: completion)
    }
    
    // MARK: - Playback Reporting
    
    private var deviceId: String {
        // Use a consistent device ID for session tracking
        if let storedId = UserDefaults.standard.string(forKey: "jellyfin_device_id") {
            return storedId
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "jellyfin_device_id")
        return newId
    }
    
    private var authHeader: String {
        "MediaBrowser Client=\"PrismPlay\", Device=\"iOS\", DeviceId=\"\(deviceId)\", Version=\"1.0.0\", Token=\"\(accessToken)\""
    }
    
    /// Reports that playback has started for an item
    func reportPlaybackStart(itemId: String, positionTicks: Int64 = 0) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else { return }
        
        let urlString = "\(serverURL)/Sessions/Playing"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(authHeader, forHTTPHeaderField: "X-Emby-Authorization")
        
        let body: [String: Any] = [
            "ItemId": itemId,
            "PositionTicks": positionTicks,
            "PlayMethod": "DirectStream",
            "CanSeek": true
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Error encoding playback start: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Error reporting playback start: \(error)")
            }
        }.resume()
    }
    
    /// Reports current playback progress
    func reportPlaybackProgress(itemId: String, positionTicks: Int64, isPaused: Bool = false) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else { return }
        
        let urlString = "\(serverURL)/Sessions/Playing/Progress"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(authHeader, forHTTPHeaderField: "X-Emby-Authorization")
        
        let body: [String: Any] = [
            "ItemId": itemId,
            "PositionTicks": positionTicks,
            "IsPaused": isPaused,
            "PlayMethod": "DirectStream",
            "CanSeek": true
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Error encoding playback progress: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("Error reporting playback progress: \(error)")
            }
        }.resume()
    }
    
    /// Reports that playback has stopped
    func reportPlaybackStopped(itemId: String, positionTicks: Int64) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else { return }
        
        let urlString = "\(serverURL)/Sessions/Playing/Stopped"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(authHeader, forHTTPHeaderField: "X-Emby-Authorization")
        
        let body: [String: Any] = [
            "ItemId": itemId,
            "PositionTicks": positionTicks
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Error encoding playback stopped: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("Error reporting playback stopped: \(error)")
            }
        }.resume()
    }
}
