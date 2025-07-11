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
    var songStatus: PlayType? = nil
    var pieceType: PieceType? = nil

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
        songStatus = nil
        pieceType = nil
    }

    func addSong(mediaSources: [(String, MediaType)]) {
        
        let current = Int(currentPlays) ?? 0
        let goal = Int(goalPlays) ?? -1

        let song = Song(title: title, studentID: student.id)
        song.songStatus = songStatus
        song.pieceType = pieceType

        for (link, type) in mediaSources {
            if let url = URL(string: link), !link.isEmpty {
                let media = MediaReference(type: type, url: url)
                media.song = song
                if song.media == nil {
                    song.media = []
                }
                song.media?.append(media)
            }
        }

        if current > 0 {
            let play = Play(count: current)
            play.song = song
            if song.plays == nil {
                song.plays = []
            }
            song.plays?.append(play)
        }
        
        if goal >= 0 {
            song.goalPlays = goal
        }


        context.insert(song)
        try? context.save()

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

