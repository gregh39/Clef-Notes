//
//  AudioRecording.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/16/25.
//
import SwiftUI
import Foundation
import SwiftData

@Model
final class AudioRecording {
    @Attribute(.unique) var id: UUID = UUID() // Explicit ID
    var title: String?
    var filename: String
    var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }
    var dateRecorded: Date
    var duration: TimeInterval?

    @Relationship var session: PracticeSession?
    
    // The new relationship to link songs to a recording.
    @Relationship(inverse: \Song.recordings) var songs: [Song] = []

    init(fileURL: URL, dateRecorded: Date = .now, title: String? = nil, duration: TimeInterval? = nil) {
        self.filename = fileURL.lastPathComponent
        self.dateRecorded = dateRecorded
        self.title = title
        self.duration = duration
    }
}
