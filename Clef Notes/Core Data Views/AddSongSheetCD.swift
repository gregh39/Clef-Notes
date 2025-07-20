//
//  AddSongSheetCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//


import SwiftUI
import CoreData
import PhotosUI

struct MediaEntry: Identifiable {
    let id = UUID()
    var urlString: String = ""
    var type: MediaType = .youtubeVideo
    
    // Properties for handling local file selections
    var photoPickerItem: PhotosPickerItem? = nil
    var audioFileURL: URL? = nil
}

struct AddSongSheetCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let student: StudentCD

    @State private var title: String = ""
    @State private var composer: String = ""
    @State private var goalPlays: String = ""
    @State private var songStatus: PlayType? = nil
    @State private var pieceType: PieceType? = nil
    @State private var mediaEntries: [MediaEntry] = []
    
    @State private var isImportingAudio = false
    @State private var selectedMediaEntryID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Composer (Optional)", text: $composer)
                } header: {
                    Text("Song Info")
                } footer: {
                    Text("Enter the title and composer of the piece.")
                }
                
                Section {
                    Picker(selection: $pieceType) {
                        Text("None").tag(PieceType?.none)
                        ForEach(PieceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(Optional(type))
                        }
                    } label: {
                        Label("Piece Type", systemImage: "music.note.list")
                    }
                    
                    Picker(selection: $songStatus) {
                        Text("None").tag(PlayType?.none)
                        ForEach(PlayType.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(Optional(status))
                        }
                    } label: {
                        Label("Initial Status", systemImage: "tag.fill")
                    }
                }
                
                Section {
                    TextField("Goal Plays (Optional)", text: $goalPlays)
                        .keyboardType(.numberPad)
                } footer: {
                    Text("Set a target number of plays for songs with a 'Practice' status.")
                }


                Section("Media Links") {
                    // --- THIS IS THE FIX: The UI for each media entry is now implemented ---
                    ForEach($mediaEntries) { $entry in
                        VStack(alignment: .leading) {
                            Picker("Type", selection: $entry.type) {
                                ForEach(MediaType.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }

                            switch entry.type {
                            case .localVideo:
                                PhotosPicker("Select Video", selection: $entry.photoPickerItem, matching: .videos)
                                if entry.photoPickerItem != nil {
                                    Text("Video selected").font(.caption).foregroundColor(.secondary)
                                }
                            case .audioRecording:
                                Button("Select Audio File") {
                                    selectedMediaEntryID = entry.id
                                    isImportingAudio = true
                                }
                                if let url = entry.audioFileURL {
                                    Text(url.lastPathComponent).font(.caption).foregroundColor(.secondary)
                                }
                            default:
                                TextField("Enter URL", text: $entry.urlString)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { mediaEntries.remove(atOffsets: $0) }

                    Button(action: {
                        withAnimation {
                            mediaEntries.append(MediaEntry())
                        }
                    }) {
                        Label("Add Media Link", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("New Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSong()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .fileImporter(isPresented: $isImportingAudio, allowedContentTypes: [.audio]) { result in
                if case .success(let url) = result, let index = mediaEntries.firstIndex(where: { $0.id == selectedMediaEntryID }) {
                    mediaEntries[index].audioFileURL = url
                }
            }
        }
    }

    private func addSong() {
        let newSong = SongCD(context: viewContext)
        newSong.title = title
        newSong.composer = composer
        newSong.studentID = student.id
        newSong.student = student
        newSong.goalPlays = Int64(goalPlays) ?? 0
        newSong.songStatus = songStatus
        newSong.pieceType = pieceType

        Task {
            for entry in mediaEntries {
                let mediaReference: MediaReferenceCD?
                
                switch entry.type {
                case .localVideo:
                    if let item = entry.photoPickerItem, let data = try? await item.loadTransferable(type: Data.self) {
                        mediaReference = MediaReferenceCD(context: viewContext)
                        mediaReference?.type = .localVideo
                        mediaReference?.data = data
                    } else { mediaReference = nil }
                case .audioRecording:
                    if let url = entry.audioFileURL, url.startAccessingSecurityScopedResource(), let data = try? Data(contentsOf: url) {
                        url.stopAccessingSecurityScopedResource()
                        mediaReference = MediaReferenceCD(context: viewContext)
                        mediaReference?.type = .audioRecording
                        mediaReference?.data = data
                    } else { mediaReference = nil }
                default:
                    if let url = URL(string: entry.urlString) {
                        mediaReference = MediaReferenceCD(context: viewContext)
                        mediaReference?.type = entry.type
                        mediaReference?.url = url
                    } else { mediaReference = nil }
                }

                if let newMedia = mediaReference {
                    newMedia.song = newSong
                    newMedia.student = student
                }            }
            
            try? viewContext.save()
        }
    }
}
