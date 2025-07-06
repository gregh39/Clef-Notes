//
//  StudentPracticeViewModel.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/10/25.
//


import Foundation
import SwiftData
import SwiftUI
import Combine

@Observable
class StudentPracticeViewModel {
    let student: Student
    var sessions: [PracticeSession] = []
    var songs: [Song] = []

    private var context: ModelContext

    init(student: Student, context: ModelContext) {
        self.student = student
        self.context = context
        fetchSessions()
        fetchSongs()
    }

    func fetchSessions() {
        let studentID = student.id
        let descriptor = FetchDescriptor<PracticeSession>(
            predicate: #Predicate { $0.studentID == studentID },
            sortBy: [SortDescriptor(\.day, order: .reverse)]
        )
        do {
            sessions = try context.fetch(descriptor)
        } catch {
            print("Error fetching sessions: \(error)")
        }
    }
    
    func fetchSongs() {
        let studentID = student.id
        let descriptor = FetchDescriptor<Song>(
            predicate: #Predicate { $0.studentID == studentID },
            sortBy: [SortDescriptor(\.title)]
        )
        do {
            songs = try context.fetch(descriptor)
        } catch {
            print("Error fetching songs: \(error)")
        }
    }
    
    func addPracticeSession(duration: Int, day: Date = Date()) {
        let session = PracticeSession(day: day, durationMinutes: duration, studentID: student.id)
        session.student = student
        context.insert(session)
        try? context.save()
        fetchSessions()
    }

    func addSong(title: String,  composer: String? = nil, goalPlays: Int? = nil) {
        let song = Song(title: title, composer: composer, goalPlays: goalPlays, studentID: student.id)
        song.student = student
        context.insert(song)
        try? context.save()
        fetchSongs()
    }

    func progress(for song: Song) -> Double {
        let total = Double(song.totalGoalPlayCount)
        guard let goalPlays = song.goalPlays, goalPlays > 0 else { return 0.0 }
        let goal = Double(goalPlays)
        return min(total / goal, 1.0)
    }
    
    func reload() {
        fetchSongs()
        fetchSessions()
    }
}
