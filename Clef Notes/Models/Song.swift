//
//  Song.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/12/25.
//
import SwiftData
import Foundation

enum MediaType: String, Codable, CaseIterable, Identifiable {
    case audioRecording = "Audio"
    case youtubeVideo = "YouTube"
    case spotifyLink = "Spotify"
    case appleMusicLink = "Apple Music"
    case sheetMusic = "Sheet Music"
    case localVideo = "Local Video"

    var id: String { rawValue }
}

enum PieceType: String, Codable, CaseIterable {
    case song = "Song"
    case scale = "Scale"
    case warmUp = "Warm-up"
    case exercise = "Exercise"
}

@Model
final class Song: Codable {
    
    var title: String = ""
    var composer: String?
    var goalPlays: Int?
    var studentID: UUID = UUID()
    var songStatus: PlayType?
    var pieceType: PieceType?

    var student: Student?
    @Relationship(deleteRule: .cascade) var plays: [Play]? = []
    @Relationship(deleteRule: .cascade) var media: [MediaReference]? = []
    var notes: [Note]? = []

    @Relationship var recordings: [AudioRecording]? = []
    
    // --- NEW: Efficiently calculates all cumulative totals at once ---
    // This computed property replaces all other calculation logic.
    @Transient
    var cumulativeTotalsByType: [Play: Int] {
        guard let plays = self.plays else { return [:] }
        var allTotals: [Play: Int] = [:]

        // Group plays by their type for separate counting.
        let playsByType = Dictionary(grouping: plays.compactMap { $0 }, by: { $0.playType })

        // Iterate over each group (e.g., all "Practice" plays).
        for (_, playsInGroup) in playsByType {
            // Sort the plays within this group just once.
            let sortedPlays = playsInGroup.sorted {
                ($0.session?.day ?? .distantPast) < ($1.session?.day ?? .distantPast)
            }

            var runningTotal = 0
            for play in sortedPlays {
                runningTotal += play.count
                allTotals[play] = runningTotal // Store the final cumulative total for this play.
            }
        }
        return allTotals
    }

    init(title: String, composer: String? = nil, studentID: UUID) {
        self.title = title
        self.composer = composer
        self.studentID = studentID
    }
    
    enum CodingKeys: String, CodingKey {
        case title
        case composer
        case goalPlays
        case studentID
        case songStatus
        case pieceType
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let title = try container.decode(String.self, forKey: .title)
        let composer = try container.decodeIfPresent(String.self, forKey: .composer)
        let goalPlays = try container.decodeIfPresent(Int.self, forKey: .goalPlays)
        let studentID = try container.decode(UUID.self, forKey: .studentID)
        let songStatus = try container.decodeIfPresent(PlayType.self, forKey: .songStatus)
        let pieceType = try container.decodeIfPresent(PieceType.self, forKey: .pieceType)
        self.init(title: title, composer: composer, studentID: studentID)
        self.songStatus = songStatus
        self.pieceType = pieceType
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(composer, forKey: .composer)
        try container.encodeIfPresent(goalPlays, forKey: .goalPlays)
        try container.encode(studentID, forKey: .studentID)
        try container.encodeIfPresent(songStatus, forKey: .songStatus)
        try container.encodeIfPresent(pieceType, forKey: .pieceType)
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
/*
    /// Returns the cumulative count for the given play's type up to and including that play, chronologically.
    func cumulativeTypeCount(for play: Play) -> Int {
        guard let plays = self.plays, let type = play.playType else { return play.count }
        // Sort all plays for this song by session day
        let sorted = plays.filter { $0.playType == type }.sorted {
            ($0.session?.day ?? .distantPast) < ($1.session?.day ?? .distantPast)
        }
        guard let idx = sorted.firstIndex(of: play) else { return play.count }
        let total = sorted.prefix(upTo: idx).reduce(0) { $0 + $1.count } + play.count
        return total
    }
 */
}
