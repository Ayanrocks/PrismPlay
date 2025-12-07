@preconcurrency import Foundation

struct JellyfinServerConfig: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let name: String
    let url: String
    let username: String
    let accessToken: String
    let userId: String
}

struct JellyfinAuthResponse: Codable, Sendable {
    let User: JellyfinUser
    let AccessToken: String
    let ServerId: String
}

struct JellyfinUser: Codable, Sendable {
    let Name: String
    let Id: String
    // Add other properties as needed
}

struct JellyfinItemsResponse: Codable, Sendable {
    let Items: [JellyfinItem]
}

struct JellyfinItem: Codable, Identifiable, Sendable {
    let Name: String
    let Id: String
    let ItemType: String
    let ImageTags: [String: String]?
    
    var id: String { Id }
    
    enum CodingKeys: String, CodingKey {
        case Name
        case Id
        case ItemType = "Type"
        case ImageTags
    }
    
    // Helper to get primary image tag
    var primaryImageTag: String? {
        return ImageTags?["Primary"]
    }
}

struct JellyfinLibrary: Codable, Identifiable, Sendable {
    let Name: String
    let Id: String
    let CollectionType: String?
    
    var id: String { Id }
}

struct JellyfinLibrariesResponse: Codable, Sendable {
    let Items: [JellyfinLibrary]
}
