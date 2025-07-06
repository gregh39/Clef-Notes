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
final class Song: Codable {
    var title: String = ""
    var composer: String?
    var goalPlays: Int?
    var studentID: UUID = UUID()

    var student: Student?
    @Relationship(deleteRule: .cascade) var plays: [Play]? = []
    @Relationship(deleteRule: .cascade) var media: [MediaReference]? = []
    var notes: [Note]? = []

    @Relationship var recordings: [AudioRecording]? = []
    

    init(title: String, composer: String? = nil, goalPlays: Int? = nil, studentID: UUID) {
        self.title = title
        self.composer = composer
        self.goalPlays = goalPlays
        self.studentID = studentID
    }

    enum CodingKeys: String, CodingKey {
        case title
        case composer
        case goalPlays
        case studentID
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let title = try container.decode(String.self, forKey: .title)
        let composer = try container.decodeIfPresent(String.self, forKey: .composer)
        let goalPlays = try container.decodeIfPresent(Int.self, forKey: .goalPlays)
        let studentID = try container.decode(UUID.self, forKey: .studentID)
        self.init(title: title, composer: composer, goalPlays: goalPlays, studentID: studentID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(composer, forKey: .composer)
        try container.encodeIfPresent(goalPlays, forKey: .goalPlays)
        try container.encode(studentID, forKey: .studentID)
    }

    // Computed properties are not encoded
    var totalPlayCount: Int {
        (plays ?? []).reduce(0) { $0 + $1.count }
    }

    var totalGoalPlayCount: Int {
        (plays ?? []).filter { $0.playType == .practice }.reduce(0) { $0 + $1.count }
    }

    var lastPlayedDate: Date? {
        (plays ?? []).map(\.session?.day).compactMap { $0 }.max()
    }
}

