// EditSongSheet.swift

import SwiftUI
import SwiftData
import PhotosUI

struct EditSongSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // --- MODIFIED: Use @Bindable for direct two-way binding ---
    @Bindable var song: Song

    // State for adding new media remains, as it's view-specific
    @State private var newMediaURL: String = ""
    @State private var newMediaType: MediaType = .youtubeVideo
    @State private var selectedVideoItem: PhotosPickerItem? = nil
    @State private var videoFileURL: URL? = nil

    // The initializer is no longer needed, as @Bindable handles it.

    var body: some View {
        NavigationStack {
            Form {
                Section("Song Details") {
                    // --- MODIFIED: Bind directly to song properties ---
                    TextField("Title", text: $song.title)
                    
                    Picker("Status", selection: $song.songStatus) {
                        Text("None").tag(PlayType?.none)
                        ForEach(PlayType.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized).tag(PlayType?(status))
                        }
                    }
                    
                    Picker("Piece Type", selection: $song.pieceType) {
                        Text("None").tag(PieceType?(nil))
                        ForEach(PieceType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(PieceType?(type))
                        }
                    }
                }

                Section("Add Media") {
                    // (This section's logic remains the same)
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
                        dismiss()
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
    
    // ... (Helper logic for media handling remains the same) ...

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

    // --- MODIFIED: The save function is much simpler ---
    private func saveChanges() {
        // Any changes from the UI are already in the 'song' object.
        // We just need to save the context.
        try? context.save()
        dismiss()
    }
}
