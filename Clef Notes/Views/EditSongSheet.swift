// EditSongSheet.swift

import SwiftUI
import SwiftData
import PhotosUI

struct EditSongSheet: View {
    @Environment(\.modelContext) private var context
    @Binding var isPresented: Bool
    
    // The song to be edited
    let song: Song

    // State for edited properties
    @State private var editedTitle: String
    @State private var editedSongStatus: PlayType?
    @State private var editedPieceType: PieceType?

    // State for adding new media
    @State private var newMediaURL: String = ""
    @State private var newMediaType: MediaType = .youtubeVideo
    @State private var selectedVideoItem: PhotosPickerItem? = nil
    @State private var videoFileURL: URL? = nil

    init(isPresented: Binding<Bool>, song: Song) {
        self._isPresented = isPresented
        self.song = song
        // Initialize the state with the song's current values
        _editedTitle = State(initialValue: song.title)
        _editedSongStatus = State(initialValue: song.songStatus)
        _editedPieceType = State(initialValue: song.pieceType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Song Details") {
                    TextField("Title", text: $editedTitle)
                    
                    Picker("Status", selection: $editedSongStatus) {
                        Text("None").tag(PlayType?(nil))
                        ForEach(PlayType.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized).tag(PlayType?(status))
                        }
                    }
                    
                    Picker("Piece Type", selection: $editedPieceType) {
                        Text("None").tag(PieceType?(nil))
                        ForEach(PieceType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(PieceType?(type))
                        }
                    }
                }

                Section("Add Media") {
                    Picker("Type", selection: $newMediaType) {
                        ForEach(MediaType.allCases) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }

                    if newMediaType == .localVideo {
                        PhotosPicker("Select Video", selection: $selectedVideoItem, matching: .videos)

                        if let videoFileURL = videoFileURL {
                            Text(videoFileURL.lastPathComponent)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        TextField("Enter media URL", text: $newMediaURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }

                    Button("Add Media to Song") {
                        addMedia()
                    }
                    .disabled(isAddMediaButtonDisabled)
                }
            }
            .navigationTitle("Edit Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            .onChange(of: selectedVideoItem) { _, newItem in
                handleVideoSelection(item: newItem)
            }
        }
    }

    // MARK: - Helper Logic
    
    private var isAddMediaButtonDisabled: Bool {
        if newMediaType == .localVideo {
            return videoFileURL == nil
        } else {
            return newMediaURL.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func handleVideoSelection(item: PhotosPickerItem?) {
        Task {
            guard let item = item,
                  let data = try? await item.loadTransferable(type: Data.self) else { return }
            
            // Save the video data to a temporary file
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            try? data.write(to: tempURL)
            videoFileURL = tempURL
        }
    }

    private func addMedia() {
        let url: URL?
        if newMediaType == .localVideo {
            url = videoFileURL
        } else {
            url = URL(string: newMediaURL)
        }

        guard let finalURL = url else { return }
        
        let newMedia = MediaReference(type: newMediaType, url: finalURL)
        song.media?.append(newMedia)
        
        // Reset fields after adding
        newMediaURL = ""
        videoFileURL = nil
        selectedVideoItem = nil
    }

    private func saveChanges() {
        song.title = editedTitle
        song.songStatus = editedSongStatus
        song.pieceType = editedPieceType
        
        // The context will automatically save the appended media as well
        try? context.save()
        
        isPresented = false
    }
}

