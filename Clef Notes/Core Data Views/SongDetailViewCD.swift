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

// MARK: - New Components for Custom Tab Bar
/// Defines the sections for the custom bottom navigation bar.
private enum SongDetailSection: String, CaseIterable, Identifiable {
    case plays = "Plays"
    case media = "Media"
    case notes = "Notes"

    var id: String { self.rawValue }

    /// Provides the SF Symbol name for each section.
    var systemImageName: String {
        switch self {
        case .plays:
            return "music.note.list"
        case .media:
            return "folder"
        case .notes:
            return "note.text"
        }
    }
}

/// The custom bottom navigation bar view.
private struct SongDetailBottomNavBar: View {
    @Binding var selectedSection: SongDetailSection
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            ForEach(SongDetailSection.allCases) { section in
                Button(action: {
                    // Switch to the selected section
                    selectedSection = section
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: section.systemImageName)
                            .font(.system(size: 22))
                        Text(section.rawValue)
                            .font(.system(size: 10)) // Matched to original
                    }
                    // Highlight the selected section
                    .foregroundColor(selectedSection == section ? .accentColor : .gray)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 5) // Matched to original
        .padding(.bottom, 35) // Matched to original
        .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
    }
}


// MARK: - Main Detail View
struct SongDetailViewCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioManager: AudioManager
    @ObservedObject var song: SongCD

    // State for the custom navigation bar
    @State private var selectedSection: SongDetailSection = .plays

    @State private var showingEditSheet = false
    @State private var showingAddMediaSheet = false
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

    private var groupedNotes: [NoteGroup] {
        let grouped = Dictionary(grouping: song.notesArray) { note -> Date in
            let dateToUse = note.date ?? note.session?.day ?? .distantPast
            return Calendar.current.startOfDay(for: dateToUse)
        }
        
        return grouped.map { NoteGroup(date: $0, notes: $1) }.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content area that switches based on the selected section
            switch selectedSection {
            case .plays:
                playsTab
            case .media:
                mediaTab
            case .notes:
                notesTab
            }

            // The custom navigation bar is placed at the bottom
            SongDetailBottomNavBar(selectedSection: $selectedSection)
        }
        .navigationTitle(song.title ?? "Song")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingAddMediaSheet = true
                } label: {
                    Label("Add Media", systemImage: "folder.badge.plus")
                }
                
                Button {
                    showingEditSheet = true
                }
                label: {
                    Label("Edit Song", systemImage: "square.and.pencil")
                }
            }
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
        .ignoresSafeArea(edges: .bottom)
    }

    private var playsTab: some View {
        PlaysListViewCD(song: song, context: viewContext)
    }

    private var mediaTab: some View {
        let groupedMedia = Dictionary(grouping: allMediaItems, by: { $0.mediaType })
        let sortedKeys = groupedMedia.keys.sorted()

        return List {
            if allMediaItems.isEmpty {
                Text("No media has been added to this song.")
                    .foregroundColor(.secondary)
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
    }
    
    private var notesTab: some View {
        List {
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
