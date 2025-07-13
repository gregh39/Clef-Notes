import SwiftUI
import SwiftData
import PhotosUI

// This struct now mirrors the one in EditSongSheet for consistency.
struct MediaEntry: Identifiable {
    let id = UUID()
    var urlString: String = ""
    var type: MediaType = .youtubeVideo
    
    // Properties for handling local file selections
    var photoPickerItem: PhotosPickerItem? = nil
    var audioFileURL: URL? = nil
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
    
    // State to control the file importer sheet
    @State private var isImportingAudio = false
    @State private var selectedMediaEntryID: UUID?

    // The closure to perform the add action
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

                            // Show the appropriate input based on the selected media type
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
                            default: // For YouTube, Spotify, etc.
                                TextField("URL", text: $entry.urlString)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        mediaEntries.remove(atOffsets: indexSet)
                    }

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
                        addAction(mediaEntries)
                        isPresented = false
                        clearForm()
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

    private func clearForm() {
        clearAction()
        mediaEntries = []
    }
}
