//
//  Song.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/12/25.
//
import SwiftData
import Foundation

enum MediaType: String, Codable, CaseIterable {
    case audioRecording
    case youtubeVideo
    case spotifyLink
    case appleMusicLink
}

@Model
final class Song {
    var title: String
    var composer: String?
    var goalPlays: Int
    var studentID: UUID
    @Relationship var student: Student?
    @Relationship(deleteRule: .cascade) var plays: [Play] = []
    @Relationship(deleteRule: .cascade) var media: [MediaReference] = []

    init(title: String, composer: String? = nil, goalPlays: Int, studentID: UUID) {
        self.title = title
        self.composer = composer
        self.goalPlays = goalPlays
        self.studentID = studentID
    }

    var totalPlayCount: Int {
        plays.reduce(0) { $0 + $1.count }
    }
}

