import Foundation
import Combine
import SwiftUI

enum PlaybackProfile {
    case direct     // Direct stream for native iOS formats (HEVC/H.264)
    case high       // HLS with HEVC, remux if possible
    case compatible // Force safe: H264/AAC, Transcode
    
    var videoCodec: String {
        switch self {
        case .direct: return ""  // Not used for direct stream
        case .high: return "hevc,h264"  // Prefer HEVC first
        case .compatible: return "h264"
        }
    }
    
    var audioCodec: String {
        switch self {
        case .direct: return ""  // Not used for direct stream
        case .high: return "aac,ac3,eac3,mp3"
        case .compatible: return "aac"
        }
    }
    
    var segmentContainer: String {
        switch self {
        case .direct: return ""  // Not used for direct stream
        case .high: return "mp4"  // fMP4 works better for HEVC on iOS
        case .compatible: return "ts"
        }
    }
    
    var transcodingProtocol: String {
        return "hls"
    }
}

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
    
    func updateServer(at index: Int, with server: JellyfinServerConfig) {
        guard index >= 0 && index < savedServers.count else { return }
        savedServers[index] = server
        saveServers()
        
        // If this is the currently selected server, update the active connection
        if isAuthenticated && serverURL == savedServers[index].url && userId == savedServers[index].userId {
            selectServer(server)
        }
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
        
        let urlString = "\(serverURL)/Users/\(userId)/Items?Recursive=true&IncludeItemTypes=Movie,Series&Fields=PrimaryImageAspectRatio,SortName,DateCreated,UserData,RunTimeTicks,LocationType,MediaSources"
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
    
    // MARK: - Item Filtering
    
    /// Filters items to only include those with valid, playable media sources
    /// Items are filtered out if:
    /// - Their LocationType is "Virtual" or "Offline" (file doesn't exist)
    /// - They have no MediaSources at all
    /// - Their MediaSources have no valid MediaStreams (no video/audio tracks)
    /// - Their MediaSources have no valid Path or Size
    /// - They are Folder type (not Movie, Episode, or Series)
    private func filterValidItems(_ items: [JellyfinItem]) -> [JellyfinItem] {
        return items.filter { item in
            // Only allow specific valid types - reject Folder and other unknown types
            let validTypes = ["Movie", "Episode", "Series", "Season", "MusicAlbum", "Audio"]
            guard validTypes.contains(item.ItemType) else { return false }
            
            // For Movies and Episodes, require valid location and media source
            if item.ItemType == "Movie" || item.ItemType == "Episode" {
                // Check LocationType - "Virtual" or "Offline" means file doesn't exist
                if let locationType = item.LocationType {
                    if locationType == "Virtual" || locationType == "Offline" {
                        return false
                    }
                }
                
                guard let mediaSource = item.MediaSources?.first else { return false }
                
                // Check if there are valid MediaStreams with at least one video stream
                if let streams = mediaSource.MediaStreams {
                    let hasVideoStream = streams.contains { $0.StreamType == "Video" }
                    if !hasVideoStream { return false }
                } else {
                    return false
                }
                
                // Verify path exists and size > 0
                if let path = mediaSource.Path, !path.isEmpty {
                    if let size = mediaSource.Size, size > 0 {
                        return true
                    } else {
                        return false
                    }
                }
                
                // If IsRemote is true, it might be a streaming source without local path
                if mediaSource.IsRemote == true {
                    return true
                }
                
                return false
            }
            // For Series and other valid types, allow them through
            return true
        }
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
    
    // MARK: - Multi-Server Support
    
    /// Fetches libraries from a specific server without changing global state
    func fetchLibraries(for server: JellyfinServerConfig, completion: @escaping @Sendable ([JellyfinLibrary]?) -> Void) {
        let urlString = "\(server.url)/Users/\(server.userId)/Views"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("MediaBrowser Client=\"PrismPlay\", Device=\"iOS\", DeviceId=\"\(UUID().uuidString)\", Version=\"1.0.0\", Token=\"\(server.accessToken)\"", forHTTPHeaderField: "X-Emby-Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching libraries from \(server.name): \(error)")
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
                    print("Error decoding libraries from \(server.name): \(error)")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    /// Fetches library items from a specific server without changing global state
    func fetchLibraryItems(libraryId: String, for server: JellyfinServerConfig, limit: Int = 10, completion: @escaping @Sendable ([JellyfinItem]?) -> Void) {
        let urlString = "\(server.url)/Users/\(server.userId)/Items?ParentId=\(libraryId)&Limit=\(limit)&Fields=PrimaryImageAspectRatio,SortName,DateCreated,UserData,RunTimeTicks,MediaSources,LocationType&SortBy=DateCreated&SortOrder=Descending"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("MediaBrowser Client=\"PrismPlay\", Device=\"iOS\", DeviceId=\"\(UUID().uuidString)\", Version=\"1.0.0\", Token=\"\(server.accessToken)\"", forHTTPHeaderField: "X-Emby-Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching library items from \(server.name): \(error)")
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
                    let validItems = self.filterValidItems(itemsResponse.Items)
                    completion(validItems)
                } catch {
                    print("Error decoding library items from \(server.name): \(error)")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    /// Fetches resume items from a specific server without changing global state
    func fetchResumeItems(for server: JellyfinServerConfig, limit: Int = 12, completion: @escaping @Sendable ([JellyfinItem]?) -> Void) {
        let urlString = "\(server.url)/Users/\(server.userId)/Items/Resume?Limit=\(limit)&Fields=PrimaryImageAspectRatio,Overview,MediaSources,RunTimeTicks,UserData,SeriesName,SeriesId,LocationType&EnableImageTypes=Primary,Backdrop,Thumb"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("MediaBrowser Client=\"PrismPlay\", Device=\"iOS\", DeviceId=\"\(UUID().uuidString)\", Version=\"1.0.0\", Token=\"\(server.accessToken)\"", forHTTPHeaderField: "X-Emby-Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching resume items from \(server.name): \(error)")
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
                    let validItems = self.filterValidItems(itemsResponse.Items)
                    completion(validItems)
                } catch {
                    print("Error decoding resume items from \(server.name): \(error)")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    /// Gets image URL for an item from a specific server
    func imageURL(for itemId: String, imageTag: String?, type: String = "Primary", server: JellyfinServerConfig) -> URL? {
        var urlString = ""
        if type == "Backdrop" {
             urlString = "\(server.url)/Items/\(itemId)/Images/Backdrop/0"
        } else {
             urlString = "\(server.url)/Items/\(itemId)/Images/\(type)"
        }
        
        if let tag = imageTag {
            urlString += "?tag=\(tag)"
        }
        return URL(string: urlString)
    }
    
    func fetchLibraryItems(libraryId: String, limit: Int = 10, completion: @escaping @Sendable ([JellyfinItem]?) -> Void) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion(nil)
            return
        }
        
        let urlString = "\(serverURL)/Users/\(userId)/Items?ParentId=\(libraryId)&Limit=\(limit)&Fields=PrimaryImageAspectRatio,SortName,DateCreated,UserData,RunTimeTicks,MediaSources,LocationType&SortBy=DateCreated&SortOrder=Descending"
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
                    let validItems = self.filterValidItems(itemsResponse.Items)
                    completion(validItems)
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
        completion: @escaping @Sendable (([JellyfinItem]?, Int?)) -> Void
    ) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion((nil, nil))
            return
        }
        
        let urlString = "\(serverURL)/Users/\(userId)/Items?ParentId=\(libraryId)&StartIndex=\(startIndex)&Limit=\(limit)&Fields=PrimaryImageAspectRatio,SortName,DateCreated,UserData,RunTimeTicks,MediaSources,LocationType&SortBy=\(sortBy)&SortOrder=\(sortOrder)"
        guard let url = URL(string: urlString) else {
            completion((nil, nil))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("MediaBrowser Client=\"PrismPlay\", Device=\"iOS\", DeviceId=\"\(UUID().uuidString)\", Version=\"1.0.0\", Token=\"\(accessToken)\"", forHTTPHeaderField: "X-Emby-Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching library items: \(error)")
                DispatchQueue.main.async { completion((nil, nil)) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion((nil, nil)) }
                return
            }
            
            DispatchQueue.main.async {
                do {
                    let itemsResponse = try JellyfinDecoder.decode(JellyfinItemsResponse.self, from: data)
                    let validItems = self.filterValidItems(itemsResponse.Items)
                    // Return valid items AND the total record count from server (or raw count if total missing)
                    let total = itemsResponse.TotalRecordCount ?? itemsResponse.Items.count
                    completion((validItems, total))
                } catch {
                    print("Error decoding library items: \(error)")
                    completion((nil, nil))
                }
            }
        }.resume()
    }
    func fetchItems(byPersonId personId: String, limit: Int = 50, completion: @escaping @Sendable ([JellyfinItem]?) -> Void) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion(nil)
            return
        }
        
        let urlString = "\(serverURL)/Users/\(userId)/Items?PersonIds=\(personId)&Limit=\(limit)&Recursive=true&IncludeItemTypes=Movie,Series&Fields=PrimaryImageAspectRatio,SortName,DateCreated,ProductionYear,LocationType,MediaSources&SortBy=DateCreated&SortOrder=Descending"
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
        
        let urlString = "\(serverURL)/Users/\(userId)/Items?Genres=\(encodedGenre)&Limit=\(limit)&Recursive=true&IncludeItemTypes=Movie,Series&Fields=PrimaryImageAspectRatio,SortName,DateCreated,ProductionYear,LocationType,MediaSources&SortBy=DateCreated&SortOrder=Descending"
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
        let urlString = "\(serverURL)/Users/\(userId)/Items?ParentId=\(seasonId)&IncludeItemTypes=Episode&SortBy=SortName,IndexNumber&Fields=PrimaryImageAspectRatio,Overview,IndexNumber,ParentIndexNumber,MediaSources,RunTimeTicks,LocationType"
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
                    let validItems = self.filterValidItems(itemsResponse.Items)
                    completion(validItems)
                } catch {
                    print("Error decoding items: \(error)")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    // MARK: - Streaming URL
    

    
    /// Constructs a streaming URL using HLS transcoding for universal iOS compatibility
    func getStreamURL(itemId: String, profile: PlaybackProfile = .high, maxBitrate: Int? = nil) -> URL? {
        guard !serverURL.isEmpty, !accessToken.isEmpty, !userId.isEmpty else { return nil }
        
        let bitrate = maxBitrate ?? 120_000_000
        
        // Construct the URL with profile-specific parameters
        // BreakOnNonKeyFrames=true and MinSegments=1 help with seek performance
        var components = URLComponents(string: "\(serverURL)/Videos/\(itemId)/master.m3u8")
        
        components?.queryItems = [
            URLQueryItem(name: "UserId", value: userId),
            URLQueryItem(name: "api_key", value: accessToken),
            URLQueryItem(name: "MediaSourceId", value: itemId),
            URLQueryItem(name: "VideoCodec", value: profile.videoCodec),
            URLQueryItem(name: "AudioCodec", value: profile.audioCodec),
            URLQueryItem(name: "MaxAudioChannels", value: "6"),
            URLQueryItem(name: "SegmentContainer", value: profile.segmentContainer),
            URLQueryItem(name: "MinSegments", value: "1"),
            URLQueryItem(name: "BreakOnNonKeyFrames", value: "true"),
            URLQueryItem(name: "TranscodingProtocol", value: profile.transcodingProtocol),
            URLQueryItem(name: "VideoBitrate", value: String(bitrate))
        ]
        
        if profile == .compatible {
            // Force strict transcoding params for compatibility mode
            // We intentionally don't set 'Static=true' to ensure we get a transcoded stream if needed
        }
        
        return components?.url
    }
    
    /// Constructs a direct stream URL for native iOS formats (HEVC/H.264)
    /// This avoids transcoding and streams the file directly
    func getDirectStreamURL(itemId: String) -> URL? {
        guard !serverURL.isEmpty, !accessToken.isEmpty else { return nil }
        
        // Use stream.mp4 for better iOS HEVC compatibility
        let urlString = "\(serverURL)/Videos/\(itemId)/stream.mp4?static=true&api_key=\(accessToken)"
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
    
    // MARK: - Search
    
    /// Searches for items across the library matching the given query
    func searchItems(query: String, limit: Int = 50, completion: @escaping @Sendable ([JellyfinItem]?) -> Void) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion(nil)
            return
        }
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion([])
            return
        }
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(nil)
            return
        }
        
        let urlString = "\(serverURL)/Users/\(userId)/Items?SearchTerm=\(encodedQuery)&Limit=\(limit)&Recursive=true&IncludeItemTypes=Movie,Series&Fields=PrimaryImageAspectRatio,SortName,DateCreated,ProductionYear,Overview,LocationType,MediaSources&SortBy=SortName&SortOrder=Ascending"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        performRequest(url: url, completion: completion)
    }
    
    // MARK: - Resume / Continue Watching
    
    /// Fetches items that the user has partially watched (Continue Watching)
    func fetchResumeItems(limit: Int = 12, completion: @escaping @Sendable ([JellyfinItem]?) -> Void) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion(nil)
            return
        }
        
        let urlString = "\(serverURL)/Users/\(userId)/Items/Resume?Limit=\(limit)&Fields=PrimaryImageAspectRatio,Overview,MediaSources,RunTimeTicks,UserData,SeriesName,SeriesId,LocationType&EnableImageTypes=Primary,Backdrop,Thumb"
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
