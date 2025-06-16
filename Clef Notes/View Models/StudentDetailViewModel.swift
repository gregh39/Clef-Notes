//
//  StudentDetailViewModel.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/13/25.
//
import SwiftUI
import SwiftData

@Observable
class StudentDetailViewModel {
    let student: Student
    public let context: ModelContext

    @ObservationIgnored var practiceVM: StudentPracticeViewModel

    var title = ""
    var goalPlays = ""
    var currentPlays = ""
    var youtubeLink = ""
    var appleMusicLink = ""
    var spotifyLink = ""
    var localFileLink = ""

    init(student: Student, context: ModelContext) {
        self.student = student
        self.context = context
        self.practiceVM = StudentPracticeViewModel(student: student, context: context)
    }

    var songs: [Song] { practiceVM.songs }
    var sessions: [PracticeSession] { practiceVM.sessions }

    func clearSongForm() {
        title = ""
        goalPlays = ""
        currentPlays = ""
        youtubeLink = ""
        appleMusicLink = ""
        spotifyLink = ""
        localFileLink = ""
    }

    func addSong(mediaSources: [(String, MediaType)]) {
        guard let goal = Int(goalPlays) else {
            print("Invalid goalPlays value: \(goalPlays)")
            return
        }
        let current = Int(currentPlays) ?? 0

        let song = Song(title: title, goalPlays: goal, studentID: student.id)

        for (link, type) in mediaSources {
            if let url = URL(string: link), !link.isEmpty {
                let media = MediaReference(type: type, url: url)
                media.song = song
                song.media.append(media)
            }
        }

        context.insert(song)
        for _ in 0..<current {
            let play = Play(count: 1)
            play.song = song
            song.plays.append(play)
        }

        clearSongForm()
        practiceVM.reload()
    }

    func addSession() -> PracticeSession {
        let session = PracticeSession(day: .now, durationMinutes: 0, studentID: student.id)
        session.student = student
        context.insert(session)
        try? context.save()
        practiceVM.reload()
        return session
    }
    
    func deleteSong(_ song: Song) {
        context.delete(song)
        try? context.save()
        practiceVM.reload()
    }
}
