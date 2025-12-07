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
            
            do {
                let authResponse = try JSONDecoder().decode(JellyfinAuthResponse.self, from: data)
                DispatchQueue.main.async {
                    self?.serverURL = server
                    self?.userId = authResponse.User.Id
                    self?.accessToken = authResponse.AccessToken
                    self?.isAuthenticated = true
                    
                    // Save the successful login
                    self?.addServer(url: server, username: username, userId: authResponse.User.Id, accessToken: authResponse.AccessToken)
                    
                    completion(.success(true))
                }
            } catch {
                DispatchQueue.main.async {
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
        
        let urlString = "\(serverURL)/Users/\(userId)/Items?Recursive=true&IncludeItemTypes=Movie,Series&Fields=PrimaryImageAspectRatio,SortName,DateCreated"
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
            
            do {
                let itemsResponse = try JSONDecoder().decode(JellyfinItemsResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(itemsResponse.Items)
                }
            } catch {
                print("Error decoding items: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
    
    func imageURL(for itemId: String, imageTag: String?) -> URL? {
        guard !serverURL.isEmpty else { return nil }
        // /Items/{Id}/Images/Primary
        var urlString = "\(serverURL)/Items/\(itemId)/Images/Primary"
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
            
            do {
                let librariesResponse = try JSONDecoder().decode(JellyfinLibrariesResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(librariesResponse.Items)
                }
            } catch {
                print("Error decoding libraries: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
    
    func fetchLibraryItems(libraryId: String, limit: Int = 10, completion: @escaping @Sendable ([JellyfinItem]?) -> Void) {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            completion(nil)
            return
        }
        
        let urlString = "\(serverURL)/Users/\(userId)/Items?ParentId=\(libraryId)&Limit=\(limit)&Fields=PrimaryImageAspectRatio,SortName&SortBy=SortName&SortOrder=Ascending"
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
            
            do {
                let itemsResponse = try JSONDecoder().decode(JellyfinItemsResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(itemsResponse.Items)
                }
            } catch {
                print("Error decoding library items: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
}
