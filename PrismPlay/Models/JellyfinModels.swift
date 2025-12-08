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

struct MediaStream: Codable, Sendable, Identifiable {
    let Index: Int
    let Codec: String?
    let Language: String?
    let TimeBase: String?
    let VideoRange: String?
    let DisplayTitle: String?
    let Title: String?
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
    let IsExternal: Bool?
    let IsDefault: Bool?
    let IsForced: Bool?
    let SupportsExternalStream: Bool?
    let Path: String?
    
    var id: Int { Index }
    
    /// Display name for subtitle selection
    var subtitleDisplayName: String {
        if let title = Title, !title.isEmpty {
            return title
        }
        if let displayTitle = DisplayTitle, !displayTitle.isEmpty {
            return displayTitle
        }
        if let language = Language {
            return language.uppercased()
        }
        return "Subtitle \(Index)"
    }
    
    enum CodingKeys: String, CodingKey {
        case Index, Codec, Language, TimeBase, VideoRange, DisplayTitle, Title, NativesTags, Widescreen, BitRate, AspectRatio, AudioChannels, AudioSampleRate, Height, Width, AverageFrameRate, RealFrameRate, Level, Profile, IsExternal, IsDefault, IsForced, SupportsExternalStream, Path
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

struct JellyfinUserData: Codable, Sendable {
    let PlaybackPositionTicks: Int64?
    let PlayedPercentage: Double?
    let Played: Bool?
    let IsFavorite: Bool?
    let LastPlayedDate: String?
    
    /// Returns playback position in seconds
    var playbackPositionSeconds: Double {
        guard let ticks = PlaybackPositionTicks else { return 0 }
        return Double(ticks) / 10_000_000.0
    }
}

struct JellyfinItem: Codable, Identifiable, Sendable {
    let Name: String
    let Id: String
    let ItemType: String
    let ImageTags: [String: String]?
    let BackdropImageTags: [String]?
    let Overview: String?
    let RunTimeTicks: Int64?
    let Genres: [String]?
    let ProductionYear: Int?
    let CommunityRating: Double?
    let OfficialRating: String?
    let People: [JellyfinPerson]?
    let MediaSources: [MediaSourceInfo]?
    let IndexNumber: Int?
    let ParentIndexNumber: Int?
    let UserData: JellyfinUserData?
    let SeriesName: String?
    let SeriesId: String?
    
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
        case UserData
        case SeriesName
        case SeriesId
    }
    
    // Helper to get primary image tag
    var primaryImageTag: String? {
        return ImageTags?["Primary"]
    }
    
    // Helper to get backdrop image tag (first one)
    var backdropImageTag: String? {
        return BackdropImageTags?.first
    }
    
    /// Returns total runtime in seconds
    var runtimeSeconds: Double {
        guard let ticks = RunTimeTicks else { return 0 }
        return Double(ticks) / 10_000_000.0
    }
    
    /// Returns remaining time in seconds based on playback progress
    var remainingSeconds: Double {
        let total = runtimeSeconds
        let played = UserData?.playbackPositionSeconds ?? 0
        return max(0, total - played)
    }
    
    /// Returns remaining time as formatted string (e.g., "15 min left")
    var remainingTimeString: String? {
        guard let userData = UserData,
              let percentage = userData.PlayedPercentage,
              percentage > 0 && percentage < 95 else { return nil }
        
        let remaining = remainingSeconds
        let minutes = Int(remaining / 60)
        if minutes > 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m left"
        }
        return "\(minutes) min left"
    }
    
    /// Returns played percentage (0-1 scale for progress bars)
    var playedProgress: Double {
        guard let percentage = UserData?.PlayedPercentage else { return 0 }
        return min(percentage / 100.0, 1.0)
    }
    
    /// Whether this item has been partially watched
    var isPartiallyWatched: Bool {
        guard let percentage = UserData?.PlayedPercentage else { return false }
        return percentage > 0 && percentage < 95
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
