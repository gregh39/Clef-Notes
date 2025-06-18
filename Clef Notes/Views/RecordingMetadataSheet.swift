import SwiftUI
import SwiftData

struct RecordingMetadataSheet: View {
    let fileURL: URL
    let songs: [Song]
    @Binding var newRecordingTitle: String
    @Binding var selectedSongIDs: Set<PersistentIdentifier>
    var onSave: (String, Set<PersistentIdentifier>) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Recording Info") {
                    TextField("Recording Title", text: $newRecordingTitle)
                    Text(fileURL.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section("Tag Songs") {
                    if songs.isEmpty {
                        Text("No songs available.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(songs, id: \.persistentModelID) { song in
                            MultipleSelectionRow(
                                title: song.title,
                                isSelected: selectedSongIDs.contains(song.persistentModelID)
                            ) {
                                if selectedSongIDs.contains(song.persistentModelID) {
                                    selectedSongIDs.remove(song.persistentModelID)
                                } else {
                                    selectedSongIDs.insert(song.persistentModelID)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Save Recording")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(newRecordingTitle, selectedSongIDs)
                    }
                    .disabled(newRecordingTitle.isEmpty)
                }
            }
        }
    }
}

struct MultipleSelectionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                if isSelected {
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
