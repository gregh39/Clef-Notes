import SwiftUI
import CoreData
import PhotosUI

struct AddMediaSheetCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var song: SongCD

    @State private var newMediaType: MediaType = .youtubeVideo
    @State private var newMediaURLString: String = ""
    
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var selectedSheetMusicItem: PhotosPickerItem?
    @State private var isImportingAudio = false
    @State private var isImportingSheetMusic = false
    @State private var selectedAudioURL: URL?
    @State private var selectedSheetMusicURL: URL?

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section {
                        Picker(selection: $newMediaType) {
                            ForEach(MediaType.allCases) { type in
                                Label(type.rawValue.capitalized, systemImage: mediaTypeIcon(for: type)).tag(type)
                            }
                        } label: {
                            Label("Media Type", systemImage: "doc.text.magnifyingglass")
                        }
                    } header: {
                        Text("Select Media Type")
                    }

                    Section {
                        switch newMediaType {
                        case .localVideo:
                            PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                                Label("Select Video", systemImage: "video.badge.plus")
                            }
                            if selectedVideoItem != nil {
                                Text("Video selected").font(.caption).foregroundColor(.secondary)
                            }
                        case .audioRecording:
                            Button { isImportingAudio = true } label: {
                                Label("Select Audio File", systemImage: "waveform.badge.plus")
                            }
                            if let url = selectedAudioURL {
                                Text(url.lastPathComponent).font(.caption).foregroundColor(.secondary)
                            }
                        case .sheetMusic:
                            // --- THIS IS THE FIX: Separated the buttons into their own rows ---
                            PhotosPicker(selection: $selectedSheetMusicItem, matching: .images) {
                                Label("Choose from Photos", systemImage: "photo")
                            }
                            
                            Button { isImportingSheetMusic = true } label: {
                                Label("Import from Files", systemImage: "folder")
                            }
                            .buttonStyle(.plain) // Ensures the text color is correct
                            
                            if selectedSheetMusicItem != nil {
                                Text("Image selected").font(.caption).foregroundColor(.secondary)
                            } else if let url = selectedSheetMusicURL {
                                Text(url.lastPathComponent).font(.caption).foregroundColor(.secondary)
                            }
                            
                        default:
                            HStack {
                                Image(systemName: "link")
                                    .foregroundColor(.secondary)
                                TextField("Enter URL", text: $newMediaURLString)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                            }
                        }
                    } header: {
                        Text(newMediaType.rawValue)
                    } footer: {
                        Text("Add a new media reference, such as a YouTube link or a local video file, to this song.")
                    }
                }
                .addDoneButtonToKeyboard()

                SaveButtonView(title: "Add", action: {
                    Task {
                        await addMedia()
                        dismiss()
                    }
                }, isDisabled: isAddMediaButtonDisabled)
            }
            .navigationTitle("Add Media")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(isPresented: $isImportingAudio, allowedContentTypes: [.audio]) { result in
                if case .success(let url) = result {
                    selectedAudioURL = url
                }
            }
            .fileImporter(isPresented: $isImportingSheetMusic, allowedContentTypes: [.pdf, .image]) { result in
                if case .success(let url) = result {
                    selectedSheetMusicURL = url
                    selectedSheetMusicItem = nil // Clear photo picker selection if a file is chosen
                }
            }
            .onChange(of: selectedSheetMusicItem) {
                if selectedSheetMusicItem != nil {
                    selectedSheetMusicURL = nil // Clear file importer selection if a photo is chosen
                }
            }
        }
    }
    
    private func mediaTypeIcon(for type: MediaType) -> String {
        switch type {
            case .audioRecording: "waveform"
            case .youtubeVideo: "play.tv"
            case .spotifyLink: "music.note"
            case .appleMusicLink: "applelogo"
            case .sheetMusic: "doc.text"
            case .localVideo: "video"
        }
    }
    
    private var isAddMediaButtonDisabled: Bool {
        switch newMediaType {
        case .localVideo:
            return selectedVideoItem == nil
        case .audioRecording:
            return selectedAudioURL == nil
        case .sheetMusic:
            return selectedSheetMusicURL == nil && selectedSheetMusicItem == nil
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
        case .sheetMusic:
            if let item = selectedSheetMusicItem, let data = try? await item.loadTransferable(type: Data.self) {
                mediaReference.type = .sheetMusic
                mediaReference.data = data
                mediaReference.title = item.itemIdentifier ?? "Sheet Music"
            } else if let url = selectedSheetMusicURL, url.startAccessingSecurityScopedResource(), let data = try? Data(contentsOf: url) {
                url.stopAccessingSecurityScopedResource()
                mediaReference.type = .sheetMusic
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
        
        try? viewContext.save()
    }
}
