import SwiftUI
import SwiftData
import PhotosUI

struct EditSongSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var song: Song

    // State for adding new media
    @State private var newMediaType: MediaType = .youtubeVideo
    @State private var newMediaURLString: String = ""
    
    // State for file pickers
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var isImportingAudio = false
    @State private var selectedAudioURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section("Song Details") {
                    TextField("Title", text: $song.title)
                    
                    Picker("Status", selection: $song.songStatus) {
                        Text("None").tag(PlayType?.none)
                        ForEach(PlayType.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized).tag(PlayType?(status))
                        }
                    }
                    
                    Picker("Piece Type", selection: $song.pieceType) {
                        Text("None").tag(PieceType?.none)
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

                    switch newMediaType {
                    case .localVideo:
                        PhotosPicker("Select Video", selection: $selectedVideoItem, matching: .videos)
                        if selectedVideoItem != nil {
                            Text("Video selected").font(.caption).foregroundColor(.secondary)
                        }
                    case .audioRecording:
                        Button("Select Audio File") { isImportingAudio = true }
                        if let url = selectedAudioURL {
                            Text(url.lastPathComponent).font(.caption).foregroundColor(.secondary)
                        }
                    default:
                        TextField("Enter media URL", text: $newMediaURLString)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }

                    Button("Add Media to Song") {
                        Task { await addMedia() }
                    }
                    .disabled(isAddMediaButtonDisabled)
                }
            }
            .navigationTitle("Edit Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                }
            }
            .fileImporter(isPresented: $isImportingAudio, allowedContentTypes: [.audio]) { result in
                if case .success(let url) = result {
                    selectedAudioURL = url
                }
            }
        }
    }

    // MARK: - Helper Logic
    
    private var isAddMediaButtonDisabled: Bool {
        switch newMediaType {
        case .localVideo:
            return selectedVideoItem == nil
        case .audioRecording:
            return selectedAudioURL == nil
        default:
            return newMediaURLString.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func addMedia() async {
        let mediaReference: MediaReference?

        switch newMediaType {
        case .localVideo:
            if let item = selectedVideoItem, let data = try? await item.loadTransferable(type: Data.self) {
                mediaReference = MediaReference(type: .localVideo, data: data, title: "Local Video")
            } else {
                mediaReference = nil
            }
        case .audioRecording:
            if let url = selectedAudioURL, url.startAccessingSecurityScopedResource(), let data = try? Data(contentsOf: url) {
                url.stopAccessingSecurityScopedResource()
                mediaReference = MediaReference(type: .audioRecording, data: data, title: url.deletingPathExtension().lastPathComponent)
            } else {
                mediaReference = nil
            }
        default:
            if let url = URL(string: newMediaURLString) {
                mediaReference = MediaReference(type: newMediaType, url: url, title: newMediaType.rawValue)
            } else {
                mediaReference = nil
            }
        }

        if let newMedia = mediaReference {
            song.media?.append(newMedia)
            resetMediaInputFields()
        }
    }
    
    private func resetMediaInputFields() {
        newMediaType = .youtubeVideo
        newMediaURLString = ""
        selectedVideoItem = nil
        selectedAudioURL = nil
    }

    private func saveChanges() {
        try? context.save()
        dismiss()
    }
}
