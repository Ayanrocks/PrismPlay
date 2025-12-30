import Foundation
import Combine

class HLSCacheController: NSObject, ObservableObject, URLSessionDelegate {
    static let shared = HLSCacheController()
    
    private var cancellables = Set<AnyCancellable>()
    private var segmentCache: [String: TimeInterval] = [:] // Map URL to duration
    private var segments: [HLSSegment] = []
    
    // Configuration - cache next 10 mins, keep previous 5 mins
    private let lookaheadDuration: TimeInterval = 10 * 60 // 10 minutes ahead
    private let cleanupThreshold: TimeInterval = 5 * 60 // 5 minutes behind
    
    @Published var cachedRanges: [ClosedRange<Double>] = [] 
    
    struct HLSSegment {
        let url: URL
        let duration: TimeInterval
        let startTime: TimeInterval
    }
    
    private let cacheManager = VideoCacheManager.shared
    private var downloadSession: URLSession!
    
    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        self.downloadSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func startCaching(for playlistURL: URL) {
        // Reset state
        segments = []
        cachedRanges = []
        
        // Fetch and parse the playlist
        fetchDatat(from: playlistURL) { [weak self] data in
            guard let self = self, let data = data else { return }
            self.parsePlaylist(data: data, baseURL: playlistURL.deletingLastPathComponent())
        }
    }
    
    func updatePlaybackTime(_ currentTime: TimeInterval) {
        // 1. Trigger downloads for [currentTime, currentTime + 15]
        downloadSegments(from: currentTime, to: currentTime + lookaheadDuration)
        
        // 2. Cleanup [0, currentTime - 10]
        cleanupSegments(olderThan: currentTime - cleanupThreshold)
        
        // 3. Update UI state (ranges)
        updateCachedRanges()
    }
    
    private func fetchDatat(from url: URL, completion: @escaping (Data?) -> Void) {
        downloadSession.dataTask(with: url) { data, _, _ in
            completion(data)
        }.resume()
    }
    
    private func parsePlaylist(data: Data, baseURL: URL) {
        guard let content = String(data: data, encoding: .utf8) else { return }
        
        var currentSegments: [HLSSegment] = []
        var currentTime: TimeInterval = 0
        
        let lines = content.components(separatedBy: .newlines)
        var currentDuration: TimeInterval = 0
        
        for line in lines {
            if line.hasPrefix("#EXTINF:") {
                // Format: #EXTINF:10.000,
                let durationString = line
                    .replacingOccurrences(of: "#EXTINF:", with: "")
                    .components(separatedBy: ",")[0]
                currentDuration = TimeInterval(durationString) ?? 0
            } else if !line.hasPrefix("#") && !line.isEmpty {
                // This is a segment URL
                if let segmentURL = URL(string: line, relativeTo: baseURL) {
                    let segment = HLSSegment(url: segmentURL, duration: currentDuration, startTime: currentTime)
                    currentSegments.append(segment)
                    currentTime += currentDuration
                }
            }
        }
        
        DispatchQueue.main.async {
            self.segments = currentSegments
            print("Parsed \(currentSegments.count) segments. Total duration: \(currentTime)")
        }
    }
    
    private func downloadSegments(from startTime: TimeInterval, to endTime: TimeInterval) {
        let targetSegments = segments.filter { segment in
            // Intersects with [startTime, endTime]
            let segmentEnd = segment.startTime + segment.duration
            return segmentEnd > startTime && segment.startTime < endTime
        }
        
        for segment in targetSegments {
            if !cacheManager.hasFile(for: segment.url) {
                // Trigger download via CacheManager or internally
                // Using internal session for now as CacheManager is sync/file based
                downloadSegment(segment.url)
            }
        }
    }
    
    private func downloadSegment(_ url: URL) {
        // Avoid duplicate downloads
        // Real implementation should probably have a 'pending' set
        
        downloadSession.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data else { return }
            self.cacheManager.saveFile(for: url, data: data)
            DispatchQueue.main.async {
                self.updateCachedRanges()
            }
        }.resume()
    }
    
    private func cleanupSegments(olderThan time: TimeInterval) {
        guard time > 0 else { return }
        
        let oldSegments = segments.filter { ($0.startTime + $0.duration) < time }
        for segment in oldSegments {
             cacheManager.deleteFile(for: segment.url)
        }
    }
    
    private func updateCachedRanges() {
        // Consolidate adjacent cached segments into ranges
        var ranges: [ClosedRange<Double>] = []
        
        let cachedSegments = segments.filter { cacheManager.hasFile(for: $0.url) }
        
        // Sort by time
        let sorted = cachedSegments.sorted { $0.startTime < $1.startTime }
        
        for segment in sorted {
            let start = segment.startTime
            let end = segment.startTime + segment.duration
            
            if let last = ranges.last {
                if abs(last.upperBound - start) < 0.5 { // 0.5s tolerance
                    ranges.removeLast()
                    ranges.append(last.lowerBound...end)
                } else {
                    ranges.append(start...end)
                }
            } else {
                ranges.append(start...end)
            }
        }
        
        self.cachedRanges = ranges
    }
    
    func stop() {
        // Cancel all pending downloads without invalidating the session
        downloadSession.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
        // We probably also want to clear cache eventually, 
        // OR the user request says: "delete the cache when closing the app or started playing the next video"
        clearCache()
    }
    
    func clearCache() {
        cacheManager.clearCache()
        cachedRanges = []
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            // Trust self-signed certificates for local network streaming
            if let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
}
