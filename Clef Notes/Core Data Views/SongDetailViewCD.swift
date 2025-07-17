import SwiftUI
import CoreData
import AVKit

struct SongDetailViewCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioManager: AudioManager
    @ObservedObject var song: SongCD

    @State private var showingEditSheet = false
    
    @StateObject private var audioPlayerManager: AudioPlayerManager

    init(song: Clef_Notes.SongCD, audioManager: AudioManager) {
        self.song = song
        _audioPlayerManager = StateObject(wrappedValue: AudioPlayerManager(audioManager: audioManager))
    }

    var body: some View {
        TabView {
            playsTab
                .tabItem { Label("Plays", systemImage: "music.note.list") }
            
            mediaTab
                .tabItem { Label("Media", systemImage: "link") }

            notesTab
                .tabItem { Label("Notes", systemImage: "note.text") }
        }
        .navigationTitle(song.title ?? "Song")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showingEditSheet = true }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            // EditSongSheetCD will be created next
        }
    }

    private var playsTab: some View {
        // We now pass the managed object context to the view's initializer.
        PlaysListViewCD(song: song, context: viewContext)
    }

    private var mediaTab: some View {
        List {
            Section("Media") {
                if song.mediaArray.isEmpty {
                    Text("No media has been added to this song.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(song.mediaArray) { media in
                        MediaCellCD(media: media, audioPlayerManager: audioPlayerManager)
                            .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteMedia)
                }
            }
        }
    }
    
    private var notesTab: some View {
        List {
            Section("Notes") {
                ForEach(song.notesArray) { note in
                    NoteCellCD(note: note)
                }
                .onDelete { indexSet in
                    deleteNote(at: indexSet, from: song.notesArray)
                }
            }
        }
    }
    
    private func deleteMedia(at offsets: IndexSet) {
        for index in offsets {
            let mediaToDelete = song.mediaArray[index]
            viewContext.delete(mediaToDelete)
        }
        try? viewContext.save()
    }
    
    private func deleteNote(at offsets: IndexSet, from notes: [NoteCD]) {
        for index in offsets {
            let noteToDelete = notes[index]
            viewContext.delete(noteToDelete)
        }
        try? viewContext.save()
    }
}

