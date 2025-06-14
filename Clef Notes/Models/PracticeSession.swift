//
//  PracticeSession.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/12/25.
//
import SwiftData
import SwiftUI
import Swift

@Model
final class PracticeSession: Hashable {
    var day: Date
    var durationMinutes: Int
    var studentID: UUID
    @Relationship var student: Student?
    @Relationship(deleteRule: .cascade) var plays: [Play] = []
    @Relationship(deleteRule: .cascade) var notes: [Note] = []

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
