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
final class PracticeSession: Hashable {
    var day: Date = Date()
    var durationMinutes: Int = 0
    var studentID: UUID = UUID()
    var location: LessonLocation?
    var title: String? = "Practice"
    @Relationship var student: Student?
    @Relationship var instructor: Instructor?
    @Relationship(deleteRule: .cascade) var plays: [Play] = []
    @Relationship(deleteRule: .cascade) var notes: [Note] = []
    @Relationship(deleteRule: .cascade) var recordings: [AudioRecording] = []

    init(day: Date, durationMinutes: Int, studentID: UUID) {
        self.day = day
        self.durationMinutes = durationMinutes
        self.studentID = studentID
    }

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
