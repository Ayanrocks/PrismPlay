import Foundation

class VideoCacheManager {
    static let shared = VideoCacheManager()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        let tempDir = fileManager.temporaryDirectory
        cacheDirectory = tempDir.appendingPathComponent("VideoCache", isDirectory: true)
        createCacheDirectory()
    }
    
    private func createCacheDirectory() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    func startSession(for url: URL) {
        // Ideally we might want to segregate by session, but for now a shared cache is fine
        // We could implement session-specific cleanup here if needed
    }
    
    func getFilePath(for url: URL) -> URL {
        // Create a safe filename from the URL
        let fileName = url.lastPathComponent
        // Use a hash of the full URL to avoid collisions if filenames are same across dirs
        let urlHash = String(url.absoluteString.hash)
        let safeFileName = "\(urlHash)_\(fileName)"
        return cacheDirectory.appendingPathComponent(safeFileName)
    }
    
    func hasFile(for url: URL) -> Bool {
        let path = getFilePath(for: url)
        return fileManager.fileExists(atPath: path.path)
    }
    
    func saveFile(for url: URL, data: Data) {
        let path = getFilePath(for: url)
        do {
            try data.write(to: path)
            print("Cached file saved: \(path.lastPathComponent)")
        } catch {
            print("Failed to save cached file: \(error)")
        }
    }
    
    func getFileData(for url: URL) -> Data? {
        let path = getFilePath(for: url)
        return try? Data(contentsOf: path)
    }
    
    func deleteFile(for url: URL) {
        let path = getFilePath(for: url)
        do {
            if fileManager.fileExists(atPath: path.path) {
                try fileManager.removeItem(at: path)
                print("Deleted cached file: \(path.lastPathComponent)")
            }
        } catch {
            print("Failed to delete cached file: \(error)")
        }
    }
    
    func clearCache() {
        do {
            if fileManager.fileExists(atPath: cacheDirectory.path) {
                try fileManager.removeItem(at: cacheDirectory)
                createCacheDirectory()
            }
        } catch {
            print("Failed to clear cache: \(error)")
        }
    }
    
    // Cleanup old files (older than 'maxAge' seconds)
    func cleanupOldFiles(maxAge: TimeInterval) {
        do {
            let resourceKeys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey]
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: resourceKeys)
            
            let expirationDate = Date().addingTimeInterval(-maxAge)
            
            for fileURL in fileURLs {
                if let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                   let modificationDate = resourceValues.contentModificationDate ?? resourceValues.creationDate {
                    
                    if modificationDate < expirationDate {
                        try? fileManager.removeItem(at: fileURL)
                        print("Removed old cache file: \(fileURL.lastPathComponent)")
                    }
                }
            }
        } catch {
            print("Error during cache cleanup: \(error)")
        }
    }
}
