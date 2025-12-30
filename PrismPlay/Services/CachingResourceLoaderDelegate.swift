import Foundation
import AVFoundation

class CachingResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate, URLSessionDelegate {
    private let cacheManager = VideoCacheManager.shared
    private var session: URLSession!
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        
        guard let url = loadingRequest.request.url else { return false }
        print("Intercepted request: \(url.absoluteString)")
        
        // Check if we can handle this request
        // We only handle our custom scheme 'caching-hls' or 'caching-https'
        guard let originalURL = getOriginalURL(from: url) else {
            return false
        }
        
        if cacheManager.hasFile(for: originalURL) {
            // Serve from cache
            if let data = cacheManager.getFileData(for: originalURL) {
                print("Serving from cache: \(originalURL.lastPathComponent)")
                loadingRequest.contentInformationRequest?.contentType = self.detectContentType(for: originalURL)
                loadingRequest.contentInformationRequest?.contentLength = Int64(data.count)
                loadingRequest.contentInformationRequest?.isByteRangeAccessSupported = true
                loadingRequest.dataRequest?.respond(with: data)
                loadingRequest.finishLoading()
                return true
            }
        }
        
        // Not in cache, download it
        downloadAndCache(url: originalURL, loadingRequest: loadingRequest)
        
        return true
    }
    
    private func getOriginalURL(from url: URL) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        // Revert scheme to https/http
        if components?.scheme == "caching-hls" {
            components?.scheme = "https" // Default assumption, might need logic for http
        } else if components?.scheme == "caching-http" {
            components?.scheme = "http"
        }
        return components?.url
    }
    
    private func downloadAndCache(url: URL, loadingRequest: AVAssetResourceLoadingRequest) {
        print("Downloading: \(url.absoluteString)")
        
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Download failed: \(error)")
                loadingRequest.finishLoading(with: error)
                return
            }
            
            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                loadingRequest.finishLoading(with: NSError(domain: "DownloadError", code: 0))
                return
            }
            
            // If it's a playlist (.m3u8), we need to modify it to use our scheme for segments
            if url.pathExtension == "m3u8" || httpResponse.mimeType == "application/x-mpegURL" || httpResponse.mimeType == "application/vnd.apple.mpegurl" {
                if let modifiedData = self.processPlaylist(data: data, originalURL: url) {
                    self.finishRequest(loadingRequest: loadingRequest, data: modifiedData, response: httpResponse)
                    // We typically DON'T cache the master playlist as it might be dynamic (live) or contain tokens
                    // But for VOD it's okay. For now let's NOT cache m3u8 to be safe and always fetch fresh
                    return
                }
            }
            
            // It's a media segment or key
            self.cacheManager.saveFile(for: url, data: data)
            self.finishRequest(loadingRequest: loadingRequest, data: data, response: httpResponse)
        }
        task.resume()
    }
    
    private func finishRequest(loadingRequest: AVAssetResourceLoadingRequest, data: Data, response: HTTPURLResponse) {
        loadingRequest.contentInformationRequest?.contentType = response.mimeType ?? detectContentType(for: response.url!)
        loadingRequest.contentInformationRequest?.contentLength = Int64(data.count)
        loadingRequest.contentInformationRequest?.isByteRangeAccessSupported = true
        
        if let dataRequest = loadingRequest.dataRequest {
            dataRequest.respond(with: data)
        }
        loadingRequest.finishLoading()
    }
    
    private func processPlaylist(data: Data, originalURL: URL) -> Data? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        
        // Simple string replacement for now.
        // We need to replace absolute URLs with custom scheme
        // And relative URLs need to be made absolute with custom scheme
        
        var newLines: [String] = []
        let baseURL = originalURL.deletingLastPathComponent()
        
        string.enumerateLines { line, _ in
            if line.hasPrefix("#") {
                newLines.append(line)
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                // It's a URI line
                if let uri = URL(string: line) {
                    if uri.scheme != nil {
                        // Absolute URL
                        let replaced = line.replacingOccurrences(of: "https://", with: "caching-hls://")
                                           .replacingOccurrences(of: "http://", with: "caching-http://")
                        newLines.append(replaced)
                    } else {
                        // Relative URL - make it absolute with our scheme
                        // NOTE: This assumes original was https.
                        // We need to know if original was http or https.
                        
                        // Construct absolute URL
                        if let absoluteURL = URL(string: line, relativeTo: baseURL) {
                             // Get the full string
                             var newUrlString = absoluteURL.absoluteString
                             // process scheme
                             newUrlString = newUrlString.replacingOccurrences(of: "https://", with: "caching-hls://")
                                                        .replacingOccurrences(of: "http://", with: "caching-http://")
                             newLines.append(newUrlString)
                        } else {
                             newLines.append(line) // Fallback
                        }
                    }
                } else {
                    newLines.append(line)
                }
            } else {
                newLines.append(line)
            }
        }
        
        return newLines.joined(separator: "\n").data(using: .utf8)
    }
    
    private func detectContentType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "m3u8": return "application/x-mpegURL"
        case "ts": return "video/MP2T"
        case "mp4": return "video/mp4"
        case "aac": return "audio/aac"
        default: return "application/octet-stream"
        }
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
