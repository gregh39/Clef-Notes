import SwiftUI
import CoreData
import PhotosUI

struct EditSongSheetCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var song: SongCD

    @State private var title: String = ""
    // --- THIS IS THE FIX: Added state for the composer ---
    @State private var composer: String = ""
    @State private var songStatus: PlayType?
    @State private var pieceType: PieceType?

    @State private var newMediaType: MediaType = .youtubeVideo
    @State private var newMediaURLString: String = ""
    
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var isImportingAudio = false
    @State private var selectedAudioURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    // --- THIS IS THE FIX: Added the TextField for the composer ---
                    TextField("Composer", text: $composer)
                } header: {
                    Text("Song Details")
                }

                Section {
                    Picker(selection: $pieceType) {
                        Text("None").tag(PieceType?.none)
                        ForEach(PieceType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(PieceType?(type))
                        }
                    } label: {
                        Label("Piece Type", systemImage: "music.note.list")
                    }
                    
                    Picker(selection: $songStatus) {
                        Text("None").tag(PlayType?.none)
                        ForEach(PlayType.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized).tag(PlayType?(status))
                        }
                    } label: {
                        Label("Status", systemImage: "tag.fill")
                    }
                }

                Section {
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
                } header: {
                    Text("Add Media")
                } footer: {
                    Text("Any media added here will be linked to this song.")
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
            .onAppear {
                title = song.title ?? ""
                // --- THIS IS THE FIX: Populate composer state ---
                composer = song.composer ?? ""
                songStatus = song.songStatus
                pieceType = song.pieceType
            }
        }
    }

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
        let mediaReference = MediaReferenceCD(context: viewContext)
        mediaReference.song = song
        mediaReference.student = song.student

        switch newMediaType {
        case .localVideo:
            if let item = selectedVideoItem, let data = try? await item.loadTransferable(type: Data.self) {
                mediaReference.type = .localVideo
                mediaReference.data = data
                mediaReference.title = "Local Video"
            }
        case .audioRecording:
            if let url = selectedAudioURL, url.startAccessingSecurityScopedResource(), let data = try? Data(contentsOf: url) {
                url.stopAccessingSecurityScopedResource()
                mediaReference.type = .audioRecording
                mediaReference.data = data
                mediaReference.title = url.deletingPathExtension().lastPathComponent
            }
        default:
            if let url = URL(string: newMediaURLString) {
                mediaReference.type = newMediaType
                mediaReference.url = url
                mediaReference.title = newMediaType.rawValue
            }
        }

        resetMediaInputFields()
    }
    
    private func resetMediaInputFields() {
        newMediaType = .youtubeVideo
        newMediaURLString = ""
        selectedVideoItem = nil
        selectedAudioURL = nil
    }

    private func saveChanges() {
        song.title = title
        // --- THIS IS THE FIX: Save composer changes ---
        song.composer = composer
        song.songStatus = songStatus
        song.pieceType = pieceType
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to save song changes: \(error)")
        }
    }
}
