import SwiftUI
import SwiftData

struct AddNoteSheet: View {
    @Bindable var note: Note
    
    // State to control UI
    @State private var showSketchArea: Bool
    @State private var selectedDetent: PresentationDetent

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Song.title) private var songs: [Song]
    
    // Use a larger frame height for the canvas on iPad.
    private var canvasHeight: CGFloat {
        // Adjust height for the large detent, providing ample space.
        UIDevice.current.userInterfaceIdiom == .pad ? 600 : 400
    }

    // Custom initializer to set the initial state of the sketch area and sheet size.
    init(note: Note) {
        self.note = note
        
        let hasDrawing = !(note.drawing?.isEmpty ?? true)
        _showSketchArea = State(initialValue: hasDrawing)
        // Set the initial sheet size based on whether there's a drawing.
        _selectedDetent = State(initialValue: hasDrawing ? .large : .medium)
    }
    
    private var drawingBinding: Binding<Data> {
        Binding(
            get: { note.drawing ?? Data() },
            set: { note.drawing = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            // Using a Form ensures content is scrollable in the .medium detent.
            Form {
                Section("Note") {
                    TextField("Enter note text", text: $note.text, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Button {
                        withAnimation {
                            showSketchArea.toggle()
                            // When showing the sketch, expand the sheet to .large.
                            // When hiding, return to .medium.
                            selectedDetent = showSketchArea ? .large : .medium
                        }
                    } label: {
                        Label(showSketchArea ? "Hide Sketch" : "Add Sketch", systemImage: showSketchArea ? "pencil.slash" : "pencil.and.scribble")
                    }
                }
                
                if showSketchArea {
                    Section("Sketch") {
                        DrawingView(drawingData: drawingBinding)
                            .frame(height: canvasHeight)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }

                Section("Tag Songs") {
                    Picker("Add Song", selection: Binding<Song?>(
                        get: { nil },
                        set: { selected in
                            if let song = selected {
                                if note.songs == nil {
                                    note.songs = []
                                }
                                if !(note.songs?.contains(song) ?? false) {
                                    note.songs?.append(song)
                                    // --- THIS IS THE FIX ---
                                    // Establish the inverse relationship by telling the song about the note.
                                    song.notes?.append(note)
                                }
                            }
                        }
                    )) {
                        Text("Select a song...").tag(Optional<Song>.none)
                        ForEach(songs) { song in
                            Text(song.title).tag(Optional(song))
                        }
                    }
                    .pickerStyle(.menu)

                    if let taggedSongs = note.songs, !taggedSongs.isEmpty {
                        ForEach(taggedSongs) { taggedSong in
                            HStack {
                                Text(taggedSong.title)
                                Spacer()
                                Button(role: .destructive) {
                                    // When removing, also break the inverse relationship
                                    note.songs?.removeAll { $0.id == taggedSong.id }
                                    taggedSong.notes?.removeAll { $0.id == note.id }
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button(role: .destructive) {
                            context.delete(note)
                            dismiss()
                        } label: {
                            Label("Delete Note", systemImage: "trash")
                        }
                        Spacer()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        try? context.save()
                        dismiss()
                    }
                    .disabled(note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (note.drawing?.isEmpty ?? true))
                }
            }
            .presentationDetents([.medium, .large], selection: $selectedDetent)
            .presentationDragIndicator(selectedDetent == .large ? .hidden : .visible)
        }
    }
}
