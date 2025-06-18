//
//  Song.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/12/25.
//
import SwiftData
import Foundation

enum MediaType: String, Codable, CaseIterable {
    case audioRecording = "Audio"
    case youtubeVideo = "YouTube"
    case spotifyLink = "Spotify"
    case appleMusicLink = "Apple Music"
    case sheetMusic = "Sheet Music"
    case localVideo = "Local Video"

}

@Model
final class Song {
    var title: String
    var composer: String?
    var goalPlays: Int?
    var studentID: UUID
    @Relationship var student: Student?
    @Relationship(deleteRule: .cascade) var plays: [Play] = []
    @Relationship(deleteRule: .cascade) var media: [MediaReference] = []

    // The inverse parameter has been removed to break the circular reference.
    // SwiftData will infer the inverse from the AudioRecording model.
    @Relationship var recordings: [AudioRecording] = []

    init(title: String, composer: String? = nil, goalPlays: Int? = nil, studentID: UUID) {
        self.title = title
        self.composer = composer
        self.goalPlays = goalPlays
        self.studentID = studentID
    }

    var totalPlayCount: Int {
        plays.reduce(0) { $0 + $1.count }
    }
    
    var lastPlayedDate: Date? {
        plays.map(\.session?.day).compactMap { $0 }.max()
    }
}
