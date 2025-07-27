// Clef Notes/Core Data Views/SongDetailViewCD.swift

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

    // Helper property to get a consistent type name for grouping
    var mediaType: String {
        switch self {
        case .mediaReference(let ref):
            return ref.type?.rawValue ?? "Media"
        case .audioRecording:
            return MediaType.audioRecording.rawValue
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
    @State private var showingAddMediaSheet = false
    
    // ViewModel for the plays list, integrated directly
    @StateObject private var playsViewModel: PlaysListViewModel
    @StateObject private var audioPlayerManager: AudioPlayerManager
    
    @State private var noteToEdit: NoteCD?
    @State private var playToEdit: PlayCD?

    init(song: SongCD, audioManager: AudioManager) {
        self.song = song
        _audioPlayerManager = StateObject(wrappedValue: AudioPlayerManager(audioManager: audioManager))
        // The context is retrieved from the persistence controller to initialize the view model
        _playsViewModel = StateObject(wrappedValue: PlaysListViewModel(song: song, context: PersistenceController.shared.persistentContainer.viewContext))
    }

    private var allMediaItems: [DisplayableMedia] {
        let references = song.mediaArray.map { DisplayableMedia.mediaReference($0) }
        let recordings = song.recordingsArray.map { DisplayableMedia.audioRecording($0) }
        return references + recordings
    }

    // A new computed property to group and sort notes by date
    private var groupedNotes: [NoteGroup] {
        let grouped = Dictionary(grouping: song.notesArray) { note -> Date in
            let dateToUse = note.date ?? note.session?.day ?? .distantPast
            return Calendar.current.startOfDay(for: dateToUse)
        }
        
        // Map the dictionary to an array of NoteGroup and sort descending by date.
        return grouped.map { NoteGroup(date: $0, notes: $1) }.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section("Details") {
                NavigationLink(destination: mediaTab) {
                    Label("View Media", systemImage: "photo.on.rectangle.angled")
                }
                NavigationLink(destination: notesTab) {
                    Label("View Notes", systemImage: "note.text")
                }
            }
            
            // The content of the plays list is now directly embedded in this view
            ForEach(playsViewModel.groupedPlays, id: \.key?.objectID) { session, playsInSession in
                Section(header: Text(session?.day?.formatted(date: .abbreviated, time: .omitted) ?? "Recent Plays")) {
                    ForEach(playsInSession) { play in
                        PlayRowCD(play: play, song: song)
                            .swipeActions(edge: .leading) {
                                Button {
                                    playToEdit = play
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                    .onDelete { indexSet in
                        deletePlay(at: indexSet, from: playsInSession)
                    }
                }
            }
        }
        .navigationTitle(song.title ?? "Song")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingAddMediaSheet = true
                } label: {
                    Label("Add Media", systemImage: "plus")
                }
                
                Button("Edit") { showingEditSheet = true }
            }
        }
        .sheet(item: $playToEdit) { play in
            PlayEditSheetCD(play: play)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditSongSheetCD(song: song)
        }
        .sheet(isPresented: $showingAddMediaSheet) {
            AddMediaSheetCD(song: song)
        }
        .sheet(item: $noteToEdit) { note in
            AddNoteSheetCD(note: note)
        }
    }

    private var mediaTab: some View {
        let groupedMedia = Dictionary(grouping: allMediaItems, by: { $0.mediaType })
        let sortedKeys = groupedMedia.keys.sorted()

        return List {
            if allMediaItems.isEmpty {
                ContentUnavailableView("No Media", systemImage: "photo.stack", description: Text("No media has been added to this song."))
            } else {
                ForEach(sortedKeys, id: \.self) { key in
                    Section(header: Text(key)) {
                        ForEach(groupedMedia[key] ?? []) { item in
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
                        .onDelete { indexSet in
                            deleteMedia(at: indexSet, from: groupedMedia[key] ?? [])
                        }
                    }
                }
            }
        }
        .navigationTitle("Media")
    }
    
    private var notesTab: some View {
        List {
            if song.notesArray.isEmpty {
                 ContentUnavailableView("No Notes", systemImage: "note.text.badge.plus", description: Text("No notes have been tagged with this song."))
            } else {
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
                            deleteNote(at: indexSet, from: group.notes)
                        }
                    }
                }
            }
        }
        .navigationTitle("Notes")
    }
    
    private func deletePlay(at offsets: IndexSet, from playsInSession: [PlayCD]) {
        for offset in offsets {
            let playToDelete = playsInSession[offset]
            viewContext.delete(playToDelete)
        }
        try? viewContext.save()
    }
    
    private func deleteMedia(at offsets: IndexSet, from mediaGroup: [DisplayableMedia]) {
        for index in offsets {
            let itemToDelete = mediaGroup[index]
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
