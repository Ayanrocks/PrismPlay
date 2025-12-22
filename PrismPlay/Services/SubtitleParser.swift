import Foundation

struct SubtitleCue: Identifiable, Equatable {
    let id = UUID()
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

class SubtitleParser {
    static func parseWebVTT(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        
        // Normalize line endings and split
        let normalizedContent = content.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedContent.components(separatedBy: .newlines)
        
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Skip header lines or empty lines
            if line.isEmpty || line == "WEBVTT" || line.hasPrefix("NOTE") || line.hasPrefix("REGION") || line.hasPrefix("STYLE") {
                i += 1
                continue
            }
            
            // Look for timing line (contains "-->")
            if line.contains("-->") {
                if let result = parseCueBlock(lines: lines, timingIndex: i) {
                    cues.append(result.0)
                    i = result.endLineIndex + 1
                } else {
                    i += 1
                }
            } else {
                // Could be an identifier, check if next line is timing
                if i + 1 < lines.count && lines[i+1].contains("-->") {
                    // It's an identifier, process from next line
                    if let result = parseCueBlock(lines: lines, timingIndex: i + 1) {
                        cues.append(result.0)
                        i = result.endLineIndex + 1
                    } else {
                        i += 2 // Skip id and failed timing
                    }
                } else {
                    i += 1
                }
            }
        }
        
        print("SubtitleParser: Parsed \(cues.count) cues from \(lines.count) lines")
        if let first = cues.first {
            print("First available cue: [\(first.startTime)-\(first.endTime)] '\(first.text)'")
        }
        
        return cues.sorted { $0.startTime < $1.startTime }
    }
    
    // Returns cue and the index of the last line consumed (the blank line or end of text)
    private static func parseCueBlock(lines: [String], timingIndex: Int) -> (SubtitleCue, endLineIndex: Int)? {
        let timingLine = lines[timingIndex]
        let components = timingLine.components(separatedBy: "-->")
        
        guard components.count == 2 else { return nil }
        
        let startString = components[0].trimmingCharacters(in: .whitespaces)
        // End time might be followed by settings like "align:middle line:80%"
        let endStringRaw = components[1].trimmingCharacters(in: .whitespaces)
        let endString = endStringRaw.components(separatedBy: .whitespaces)[0]
        
        guard let startTime = parseTime(startString),
              let endTime = parseTime(endString) else { return nil }
        
        // Extract text
        var textLines: [String] = []
        var currentIndex = timingIndex + 1
        
        while currentIndex < lines.count {
            let line = lines[currentIndex] // Don't trim blindly, indents might matter, but for VTT we usually trim
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                break
            }
            textLines.append(line.trimmingCharacters(in: .whitespaces))
            currentIndex += 1
        }
        
        let text = textLines.joined(separator: "\n")
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) // Strip HTML tags
            .replacingOccurrences(of: "\\{[^\\}]+\\}", with: "", options: .regularExpression) // Strip CSS-like tags
        
        if text.isEmpty { return nil }
        
        return (SubtitleCue(startTime: startTime, endTime: endTime, text: text), endLineIndex: currentIndex)
    }
    
    private static func parseTime(_ timeString: String) -> TimeInterval? {
        let parts = timeString.components(separatedBy: ":")
        
        if parts.count == 3 {
            // HH:MM:SS.mmm
            guard let hours = Double(parts[0]),
                  let minutes = Double(parts[1]),
                  let seconds = Double(parts[2]) else { return nil }
            return hours * 3600 + minutes * 60 + seconds
        } else if parts.count == 2 {
            // MM:SS.mmm
            guard let minutes = Double(parts[0]),
                  let seconds = Double(parts[1]) else { return nil }
            return minutes * 60 + seconds
        }
        
        return nil
    }
}
