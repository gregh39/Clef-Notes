//
//  PracticeSession.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/12/25.
//
import SwiftData
import SwiftUI
import Swift

enum LessonLocation: String, Codable, CaseIterable {
    case home = "Home"
    case school = "School"
    case privateLesson = "Private Lesson"
    case clinic = "Clinic"
}

@Model
final class PracticeSession: Hashable, Codable {
    var day: Date = Date()
    var durationMinutes: Int = 0
    var studentID: UUID = UUID()
    var location: LessonLocation?
    var title: String? = "Practice"

    var student: Student?
    @Relationship var instructor: Instructor?
    @Relationship(deleteRule: .cascade) var plays: [Play]? = []
    @Relationship(deleteRule: .cascade) var notes: [Note]? = []
    @Relationship(deleteRule: .cascade, inverse: \AudioRecording.session) var recordings: [AudioRecording]? = []

    init(day: Date, durationMinutes: Int, studentID: UUID) {
        self.day = day
        self.durationMinutes = durationMinutes
        self.studentID = studentID
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case day
        case durationMinutes
        case studentID
        case location
        case title
        // Relationships excluded from Codable
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let day = try container.decode(Date.self, forKey: .day)
        let durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        let studentID = try container.decode(UUID.self, forKey: .studentID)
        self.init(day: day, durationMinutes: durationMinutes, studentID: studentID)
        self.location = try container.decodeIfPresent(LessonLocation.self, forKey: .location)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encode(studentID, forKey: .studentID)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(title, forKey: .title)
    }

    // MARK: - Hashable

    static func == (lhs: PracticeSession, rhs: PracticeSession) -> Bool {
        lhs.day == rhs.day &&
        lhs.durationMinutes == rhs.durationMinutes &&
        lhs.studentID == rhs.studentID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(day)
        hasher.combine(durationMinutes)
        hasher.combine(studentID)
    }
}
