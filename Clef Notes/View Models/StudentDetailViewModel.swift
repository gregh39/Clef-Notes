import SwiftUI
import SwiftData
import PhotosUI

@Observable
class StudentDetailViewModel {
    let student: Student
    public let context: ModelContext

    @ObservationIgnored var practiceVM: StudentPracticeViewModel

    // Simplified properties for the Add Song sheet
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

    // Updated addSong function to handle the new MediaEntry struct
    func addSong(mediaEntries: [MediaEntry]) {
        let goal = Int(goalPlays)
        
        let song = Song(title: title, studentID: student.id)
        song.songStatus = songStatus
        song.pieceType = pieceType
        song.goalPlays = goal

        context.insert(song)

        // Use a Task to handle asynchronous file loading
        Task {
            for entry in mediaEntries {
                let mediaReference: MediaReference?
                
                switch entry.type {
                case .localVideo:
                    if let item = entry.photoPickerItem, let data = try? await item.loadTransferable(type: Data.self) {
                        mediaReference = MediaReference(type: .localVideo, data: data)
                    } else {
                        mediaReference = nil
                    }
                case .audioRecording:
                    if let url = entry.audioFileURL, url.startAccessingSecurityScopedResource(), let data = try? Data(contentsOf: url) {
                        url.stopAccessingSecurityScopedResource()
                        mediaReference = MediaReference(type: .audioRecording, data: data)
                    } else {
                        mediaReference = nil
                    }
                default:
                    if let url = URL(string: entry.urlString) {
                        mediaReference = MediaReference(type: entry.type, url: url)
                    } else {
                        mediaReference = nil
                    }
                }

                if let newMedia = mediaReference {
                    // Associate the new media with the song
                    newMedia.song = song
                    if song.media == nil {
                        song.media = []
                    }
                    song.media?.append(newMedia)
                }
            }
            
            // Save the context after all media has been processed
            try? context.save()
            
            // Update the UI on the main thread
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
