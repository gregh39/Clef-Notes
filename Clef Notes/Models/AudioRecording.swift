import Foundation
import SwiftData

@Model
final class AudioRecording {
    var id: UUID = UUID()
    var title: String?
    
    // --- THIS IS THE FIX ---
    // Instead of a filename, we store the audio data directly.
    // SwiftData will handle syncing this data efficiently via CloudKit.
    @Attribute(.externalStorage)
    var data: Data?
    
    var dateRecorded: Date = Date()
    var duration: TimeInterval?

    var session: PracticeSession?
    
    @Relationship(inverse: \Song.recordings) var songs: [Song]? = []

    // The initializer now accepts the audio data.
    init(data: Data?, dateRecorded: Date = .now, title: String? = nil, duration: TimeInterval? = nil) {
        self.data = data
        self.dateRecorded = dateRecorded
        self.title = title
        self.duration = duration
    }
}
