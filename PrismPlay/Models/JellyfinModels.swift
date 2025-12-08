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

struct JellyfinPerson: Codable, Identifiable, Sendable {
    let Name: String
    let Id: String
    let Role: String?
    let PersonType: String?
    let PrimaryImageTag: String?
    
    var id: String { Id }
    
    enum CodingKeys: String, CodingKey {
        case Name
        case Id
        case Role
        case PersonType = "Type"
        case PrimaryImageTag
    }
}

struct JellyfinItemsResponse: Codable, Sendable {
    let Items: [JellyfinItem]
}

struct MediaStream: Codable, Sendable {
    let Codec: String?
    let Language: String?
    let TimeBase: String?
    let VideoRange: String?
    let DisplayTitle: String?
    let NativesTags: [String]?
    let Widescreen: Bool?
    let BitRate: Int?
    let AspectRatio: String?
    let AudioChannels: Int?
    let AudioSampleRate: Int?
    let Height: Int?
    let Width: Int?
    let AverageFrameRate: Float?
    let RealFrameRate: Float?
    let Level: Double?
    let Profile: String?
    let StreamType: String
    
    enum CodingKeys: String, CodingKey {
        case Codec, Language, TimeBase, VideoRange, DisplayTitle, NativesTags, Widescreen, BitRate, AspectRatio, AudioChannels, AudioSampleRate, Height, Width, AverageFrameRate, RealFrameRate, Level, Profile
        case StreamType = "Type"
    }
}


struct MediaSourceInfo: Codable, Identifiable, Sendable {
    let MediaProtocol: String?
    let Id: String
    let Path: String?
    let SourceType: String?
    let Container: String?
    let Size: Int64?
    let Name: String?
    let IsRemote: Bool?
    let MediaStreams: [MediaStream]?
    
    var id: String { Id }
    
    enum CodingKeys: String, CodingKey {
        case MediaProtocol = "Protocol"
        case Id
        case Path
        case SourceType = "Type"
        case Container
        case Size
        case Name
        case IsRemote
        case MediaStreams
    }
}

struct JellyfinItem: Codable, Identifiable, Sendable {
    let Name: String
    let Id: String
    let ItemType: String
    let ImageTags: [String: String]?
    let BackdropImageTags: [String]?
    let Overview: String?
    let RunTimeTicks: Int?
    let Genres: [String]?
    let ProductionYear: Int?
    let CommunityRating: Double?
    let OfficialRating: String?
    let People: [JellyfinPerson]?
    let MediaSources: [MediaSourceInfo]?
    let IndexNumber: Int?
    let ParentIndexNumber: Int?
    
    var id: String { Id }
    
    enum CodingKeys: String, CodingKey {
        case Name
        case Id
        case ItemType = "Type"
        case ImageTags
        case BackdropImageTags
        case Overview
        case RunTimeTicks
        case Genres
        case ProductionYear
        case CommunityRating
        case OfficialRating
        case People
        case MediaSources
        case IndexNumber
        case ParentIndexNumber
    }
    
    // Helper to get primary image tag
    var primaryImageTag: String? {
        return ImageTags?["Primary"]
    }
    
    // Helper to get backdrop image tag (first one)
    var backdropImageTag: String? {
        return BackdropImageTags?.first
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
