import SwiftUI
import CoreData
import AVKit

// A wrapper to display different media types in one list.
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

// A new struct to hold grouped notes
private struct NoteGroup: Identifiable {
    var id: Date { date }
    let date: Date
    let notes: [NoteCD]
}

struct SongDetailViewCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioManager: AudioManager
    @ObservedObject var song: SongCD

    @State private var showingEditSheet = false
    @StateObject private var audioPlayerManager: AudioPlayerManager
    
    @State private var noteToEdit: NoteCD?

    init(song: SongCD, audioManager: AudioManager) {
        self.song = song
        _audioPlayerManager = StateObject(wrappedValue: AudioPlayerManager(audioManager: audioManager))
    }

    private var allMediaItems: [DisplayableMedia] {
        let references = song.mediaArray.map { DisplayableMedia.mediaReference($0) }
        let recordings = song.recordingsArray.map { DisplayableMedia.audioRecording($0) }
        return references + recordings
    }

    // A new computed property to group and sort notes by date
    private var groupedNotes: [NoteGroup] {
        // --- THIS IS THE FIX: Safely unwrap the date and provide fallbacks ---
        let grouped = Dictionary(grouping: song.notesArray) { note -> Date in
            let dateToUse = note.date ?? note.session?.day ?? .distantPast
            return Calendar.current.startOfDay(for: dateToUse)
        }
        
        // Map the dictionary to an array of NoteGroup and sort descending by date.
        return grouped.map { NoteGroup(date: $0, notes: $1) }.sorted { $0.date > $1.date }
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
        .sheet(item: $noteToEdit) { note in
            AddNoteSheetCD(note: note)
        }
    }

    private var playsTab: some View {
        PlaysListViewCD(song: song, context: viewContext)
    }

    private var mediaTab: some View {
        List {
            Section("Media") {
                if allMediaItems.isEmpty {
                    Text("No media has been added to this song.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(allMediaItems) { item in
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
            // The list now iterates over the grouped notes
            ForEach(groupedNotes) { group in
                Section(header: Text(group.date, style: .date)) {
                    ForEach(group.notes) { note in
                        Button(action: {
                            noteToEdit = note
                        }) {
                            NoteCellCD(note: note)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        // The deletion logic is now scoped to the specific group
                        deleteNote(at: indexSet, from: group.notes)
                    }
                }
            }
        }
    }
    
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
