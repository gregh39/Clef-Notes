import SwiftUI
import CoreData

struct RecordingMetadataSheetCD: View {
    let fileURL: URL
    let songs: [SongCD]
    
    @Binding var newRecordingTitle: String
    @Binding var selectedSongs: Set<SongCD>
    
    var onSave: (String, Set<SongCD>) -> Void
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section("Recording Info") {
                        TextField("Recording Title", text: $newRecordingTitle)
                        Text(fileURL.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Section("Tag Songs") {
                        if songs.isEmpty {
                            Text("No songs available.").foregroundColor(.secondary)
                        } else {
                            ForEach(songs) { song in
                                MultipleSelectionRowCD(
                                    title: song.title ?? "Unknown",
                                    isSelected: selectedSongs.contains(song)
                                ) {
                                    if selectedSongs.contains(song) {
                                        selectedSongs.remove(song)
                                    } else {
                                        selectedSongs.insert(song)
                                    }
                                }
                            }
                        }
                    }
                }
                
                SaveButtonView(title: "Save", action: {
                    onSave(newRecordingTitle, selectedSongs)
                    dismiss()
                }, isDisabled: newRecordingTitle.isEmpty)
            }
            .navigationTitle("Save Recording")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct MultipleSelectionRowCD: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                if isSelected {
                    Spacer()
                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
