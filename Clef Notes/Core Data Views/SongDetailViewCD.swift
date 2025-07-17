import SwiftUI
import CoreData
import AVKit

// --- CHANGE 1: Create a wrapper to display different media types in one list ---
enum DisplayableMedia: Identifiable, Hashable {
    case mediaReference(MediaReferenceCD)
    case audioRecording(AudioRecordingCD)
    
    var id: NSManagedObjectID {
        switch self {
        case .mediaReference(let ref):
            return ref.objectID
        case .audioRecording(let rec):
            return rec.objectID
        }
    }
}

struct SongDetailViewCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioManager: AudioManager
    @ObservedObject var song: SongCD

    @State private var showingEditSheet = false
    
    @StateObject private var audioPlayerManager: AudioPlayerManager

    init(song: SongCD, audioManager: AudioManager) {
        self.song = song
        _audioPlayerManager = StateObject(wrappedValue: AudioPlayerManager(audioManager: audioManager))
    }

    // --- CHANGE 2: Create a computed property to combine both media types ---
    private var allMediaItems: [DisplayableMedia] {
        let references = song.mediaArray.map { DisplayableMedia.mediaReference($0) }
        let recordings = song.recordingsArray.map { DisplayableMedia.audioRecording($0) }
        // You can add sorting here if needed, e.g., by date
        return references + recordings
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
            EditSongSheetCD(song: song)
        }
    }

    private var playsTab: some View {
        PlaysListViewCD(song: song, context: viewContext)
    }

    private var mediaTab: some View {
        List {
            Section("Media") {
                // --- CHANGE 3: The list now iterates over the combined media items ---
                if allMediaItems.isEmpty {
                    Text("No media has been added to this song.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(allMediaItems) { item in
                        // Use a switch to display the correct cell for each type
                        switch item {
                        case .mediaReference(let media):
                            MediaCellCD(media: media, audioPlayerManager: audioPlayerManager)
                                .padding(.vertical, 4)
                        case .audioRecording(let recording):
                            AudioPlaybackCellCD(
                                title: recording.title ?? "Recording",
                                subtitle: (recording.dateRecorded ?? .now).formatted(date: .abbreviated, time: .shortened),
                                data: recording.data,
                                duration: recording.duration,
                                id: recording.objectID,
                                audioPlayerManager: audioPlayerManager
                            )
                            .padding(.vertical, 4)
                        }
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
    
    // --- CHANGE 4: Update deletion logic to handle the combined list ---
    private func deleteMedia(at offsets: IndexSet) {
        for index in offsets {
            let itemToDelete = allMediaItems[index]
            switch itemToDelete {
            case .mediaReference(let ref):
                viewContext.delete(ref)
            case .audioRecording(let rec):
                viewContext.delete(rec)
            }
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
