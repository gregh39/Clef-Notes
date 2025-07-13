import SwiftData
import SwiftUI
import AVFoundation

@Model
final class MediaReference {
    var type: MediaType = MediaType.audioRecording
    var url: URL?
    var title: String?
    var notes: String?
    
    // This property will store the length of the audio file.
    var duration: TimeInterval?
    
    @Attribute(.externalStorage)
    var data: Data?
    
    @Relationship var song: Song?

    // Initializer for URL-based media (YouTube, Spotify, etc.)
    init(type: MediaType, url: URL, title: String? = nil, notes: String? = nil) {
        self.type = type
        self.url = url
        self.title = title
        self.notes = notes
        self.data = nil
        self.duration = nil
    }
    
    // Initializer for data-based media (local audio/video files)
    init(type: MediaType, data: Data, title: String? = nil, notes: String? = nil) {
        self.type = type
        self.data = data
        self.title = title
        self.notes = notes
        self.url = nil
        
        // Calculate duration when the object is created.
        if let player = try? AVAudioPlayer(data: data) {
            self.duration = player.duration
        }
    }
}
