//
//  StudentDetailViewModel.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/13/25.
//
import SwiftUI
import SwiftData
import PhotosUI // Import for PhotosPickerItem

@Observable
class StudentDetailViewModel {
    let student: Student
    public let context: ModelContext

    @ObservationIgnored var practiceVM: StudentPracticeViewModel

    // Simplified properties
    var title = ""
    var goalPlays = ""
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
        songStatus = nil
        pieceType = nil
    }

    // Updated addSong function to handle MediaEntry array
    func addSong(mediaEntries: [MediaEntry]) {
        let goal = Int(goalPlays)
        
        let song = Song(title: title, studentID: student.id)
        song.songStatus = songStatus
        song.pieceType = pieceType
        song.goalPlays = goal

        context.insert(song)

        Task {
            for entry in mediaEntries {
                var finalURL: URL?
                
                if entry.type == .localVideo, let item = entry.photoPickerItem {
                    // Handle video item by loading its data and saving to a file
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                        try? data.write(to: tempURL)
                        finalURL = tempURL
                    }
                } else if entry.type == .audioRecording, let fileURL = entry.fileURL {
                    finalURL = fileURL
                } else if let url = URL(string: entry.url), !entry.url.isEmpty {
                    finalURL = url
                }

                if let url = finalURL {
                    let media = MediaReference(type: entry.type, url: url)
                    media.song = song
                    if song.media == nil {
                        song.media = []
                    }
                    song.media?.append(media)
                }
            }
            
            try? context.save()
            
            await MainActor.run {
                clearSongForm()
                practiceVM.reload()
            }
        }
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
