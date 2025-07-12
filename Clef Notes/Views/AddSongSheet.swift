//
//  AddSongSheet.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/13/25.
//
import SwiftUI
import SwiftData
import PhotosUI // Import for PhotosPicker

// The MediaEntry struct now includes properties to handle file selections
struct MediaEntry: Identifiable {
    let id = UUID()
    var url: String = ""
    var type: MediaType = .youtubeVideo
    var photoPickerItem: PhotosPickerItem? = nil
    var fileURL: URL? = nil // To store the URL of a selected audio file
}

struct AddSongSheet: View {
    @Binding var isPresented: Bool
    
    // Bindings for the main song details
    @Binding var title: String
    @Binding var goalPlays: String
    @Binding var songStatus: PlayType?
    @Binding var pieceType: PieceType?

    // A single state variable to hold a list of media entries
    @State private var mediaEntries: [MediaEntry] = []
    
    // State to control the file importer
    @State private var isImportingFile = false
    @State private var selectedMediaEntryID: UUID?


    // The closure to perform the add action, now accepting media entries
    var addAction: ([MediaEntry]) -> Void
    var clearAction: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Song Info") {
                    TextField("Title", text: $title)
                    TextField("Goal Plays (Optional)", text: $goalPlays)
                        .keyboardType(.numberPad)
                    
                    Picker("Piece Type", selection: $pieceType) {
                        Text("None").tag(PieceType?.none)
                        ForEach(PieceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(Optional(type))
                        }
                    }
                    
                    Picker("Status", selection: $songStatus) {
                        Text("None").tag(PlayType?.none)
                        ForEach(PlayType.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(Optional(status))
                        }
                    }
                }

                Section("Media Links") {
                    ForEach($mediaEntries) { $entry in
                        VStack(alignment: .leading) {
                            Picker("Type", selection: $entry.type) {
                                ForEach(MediaType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.menu)

                            // --- MODIFIED: Show picker or text field based on type ---
                            switch entry.type {
                            case .localVideo:
                                PhotosPicker("Select Video", selection: $entry.photoPickerItem, matching: .videos)
                                if let item = entry.photoPickerItem {
                                    // You can expand this to show a thumbnail or more details
                                    Text("Video selected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            case .audioRecording:
                                Button(action: {
                                    selectedMediaEntryID = entry.id
                                    isImportingFile = true
                                }) {
                                    Label(entry.fileURL?.lastPathComponent ?? "Select Audio File", systemImage: "folder")
                                }
                                
                            default: // For YouTube, Spotify, etc.
                                TextField("URL", text: $entry.url)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        mediaEntries.remove(atOffsets: indexSet)
                    }

                    // Button to add a new media entry row
                    Button(action: {
                        mediaEntries.append(MediaEntry())
                    }) {
                        Label("Add Media Link", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("New Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                        clearForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        // Pass the media entries to the add action
                        addAction(mediaEntries)
                        isPresented = false
                        clearForm()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.audio]) { result in
                switch result {
                case .success(let url):
                    if let index = mediaEntries.firstIndex(where: { $0.id == selectedMediaEntryID }) {
                        mediaEntries[index].fileURL = url
                    }
                case .failure(let error):
                    print("Error importing file: \(error.localizedDescription)")
                }
            }
        }
    }

    private func clearForm() {
        // Now also clears the media entries
        clearAction()
        mediaEntries = []
    }
}
