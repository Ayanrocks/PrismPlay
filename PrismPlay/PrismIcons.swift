import SwiftUI

public enum PrismIcon: String, CaseIterable {
    // MARK: - Navigation & Actions
    case back = "chevron.backward"
    case close = "xmark.circle.fill"
    case settings = "gearshape.fill"
    case more = "ellipsis.circle"
    
    // MARK: - Home & Library
    case localFiles = "internaldrive.fill"
    case jellyfin = "play.tv.fill"
    case folder = "folder.fill"
    
    // MARK: - Playback Control
    case play = "play.fill"
    case pause = "pause.fill"
    case stop = "stop.fill"
    case seekForward = "goforward.5"
    case seekBackward = "gobackward.5"
    case volumeHigh = "speaker.wave.3.fill"
    case volumeLow = "speaker.wave.1.fill"
    case volumeMute = "speaker.slash.fill"
    case rotateScreen = "arrow.triangle.2.circlepath.circle.fill"
    case airplay = "airplayvideo"
    case pip = "pip.enter"
    
    // MARK: - Accessor
    public var image: Image {
        Image(systemName: self.rawValue)
    }
    
    public var systemName: String {
        self.rawValue
    }
}
