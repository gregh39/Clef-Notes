import SwiftUI
import CoreData
import PencilKit

struct AddNoteSheetCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var note: NoteCD

    @FetchRequest private var songs: FetchedResults<SongCD>

    // Local state for editing
    @State private var noteTitle: String = ""
    @State private var noteText: String = ""
    @State private var drawingData: Data = Data()
    @State private var taggedSongs: Set<SongCD> = []
    @State private var noteDate: Date = .now

    @State private var showSketchArea: Bool
    @State private var selectedDetent: PresentationDetent
    
    @State private var showingFullScreenDrawing = false

    init(note: NoteCD) {
        self.note = note
        let hasDrawing = !(note.drawing?.isEmpty ?? true)
        _showSketchArea = State(initialValue: hasDrawing)
        _selectedDetent = State(initialValue: hasDrawing ? .large : .medium)
        
        let studentPredicate: NSPredicate
        if let student = note.student ?? note.session?.student {
            studentPredicate = NSPredicate(format: "student == %@", student)
        } else {
            studentPredicate = NSPredicate(value: false)
        }
        
        _songs = FetchRequest<SongCD>(
            sortDescriptors: [NSSortDescriptor(keyPath: \SongCD.title, ascending: true)],
            predicate: studentPredicate
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextField("Title", text: $noteTitle)
                    
                    TextField("Enter note text", text: $noteText, axis: .vertical)
                        .lineLimit(3...6)
                    
                    if note.session == nil {
                        DatePicker("Date", selection: $noteDate, displayedComponents: .date)
                    }
                    
                    Button(showSketchArea ? "Hide Sketch" : "Add Sketch") {
                        withAnimation {
                            showSketchArea.toggle()
                            selectedDetent = showSketchArea ? .large : .medium
                        }
                    }
                }
                
                if showSketchArea {
                    Section {
                        DrawingView(drawingData: $drawingData)
                            .frame(height: 300)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    } header: {
                        HStack {
                            Text("Sketch")
                            Spacer()
                            Button {
                                showingFullScreenDrawing = true
                            } label: {
                                Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Section("Tag Songs") {
                    Picker("Add Song", selection: Binding<SongCD?>(get: { nil }, set: { selected in
                        if let song = selected {
                            taggedSongs.insert(song)
                        }
                    })) {
                        Text("Select a song...").tag(Optional<SongCD>.none)
                        ForEach(songs) { song in
                            Text(song.title ?? "Unknown").tag(Optional(song))
                        }
                    }
                    
                    ForEach(Array(taggedSongs)) { taggedSong in
                        HStack {
                            Text(taggedSong.title ?? "Unknown")
                            Spacer()
                            Button(role: .destructive) {
                                taggedSongs.remove(taggedSong)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Edit Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        note.title = noteTitle
                        note.text = noteText
                        note.drawing = drawingData
                        note.songs = NSSet(array: Array(taggedSongs))
                        
                        if let session = note.session {
                            note.student = session.student
                            note.date = session.day
                        } else {
                            note.date = noteDate
                        }
                        
                        try? viewContext.save()
                        dismiss()
                    }
                }
            }
            .presentationDetents([.medium, .large], selection: $selectedDetent)
            .onAppear {
                noteTitle = note.title ?? ""
                noteText = note.text ?? ""
                drawingData = note.drawing ?? Data()
                taggedSongs = note.songs as? Set<SongCD> ?? []
                noteDate = note.date ?? .now
            }
            .fullScreenCover(isPresented: $showingFullScreenDrawing) {
                FullScreenDrawingView(drawingData: $drawingData)
            }
        }
    }
}

private struct FullScreenDrawingView: View {
    @Binding var drawingData: Data
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            DrawingView(drawingData: $drawingData)
                .edgesIgnoringSafeArea(.bottom)
                .navigationTitle("Sketch")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
