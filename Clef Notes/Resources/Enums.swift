//
//  Enums.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/18/25.
//

public enum MediaType: String, Codable, CaseIterable, Identifiable {
    case audioRecording = "Audio"
    case youtubeVideo = "YouTube"
    case spotifyLink = "Spotify"
    case appleMusicLink = "Apple Music"
    case sheetMusic = "Sheet Music"
    case localVideo = "Local Video"

    public var id: String { rawValue }
}

public enum PieceType: String, Codable, CaseIterable {
    case song = "Song"
    case scale = "Scale"
    case warmUp = "Warm-up"
    case exercise = "Exercise"
}

public enum LessonLocation: String, Codable, CaseIterable {
    case home = "Home"
    case school = "School"
    case privateLesson = "Private Lesson"
    case clinic = "Clinic"
}

public enum PlayType: String, Codable, CaseIterable {
    case learning = "Learning"
    case practice = "Practice"
    case review = "Review"
}

enum SongSortOption: String, CaseIterable, Identifiable {
    case title = "Title"
    case playCount = "Play Count"
    case recentlyPlayed = "Recently Played"

    var id: String { rawValue }
}
