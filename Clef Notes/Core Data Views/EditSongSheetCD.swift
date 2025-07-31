import SwiftUI
import CoreData
import PhotosUI

struct EditSongSheetCD: View {
    // 1. Define an enum for your focusable fields
    private enum FocusField: Hashable, CaseIterable {
        case title, composer, goalPlays
    }

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var song: SongCD

    // 2. Add the @FocusState property wrapper
    @FocusState private var focusedField: FocusField?

    @State private var title: String = ""
    @State private var composer: String = ""
    @State private var songStatus: PlayType?
    @State private var pieceType: PieceType?
    @State private var goalPlays: String = ""
    @State private var selectedSuzukiBook: SuzukiBook? = nil

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section {
                        TextField("Title", text: $title)
                            .focused($focusedField, equals: .title) // 3. Apply .focused
                        
                        TextField("Composer", text: $composer)
                            .focused($focusedField, equals: .composer) // 3. Apply .focused
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
                    
                    Section("Practice Goals") {
                        TextField("Goal Plays", text: $goalPlays)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .goalPlays) // 3. Apply .focused
                    }

                    if song.student?.suzukiStudent?.boolValue ?? false {
                        Section("Suzuki") {
                            Picker("Suzuki Book", selection: $selectedSuzukiBook) {
                                Text("Select a Book").tag(Optional<SuzukiBook>.none)
                                ForEach(SuzukiBook.allCases) { book in
                                    Text(book.rawValue).tag(Optional(book))
                                }
                            }
                        }
                    }
                }
                // 4. Apply the new navigation modifier
                .addKeyboardNavigation(for: FocusField.allCases, focus: $focusedField)
                
                SaveButtonView(title: "Save", action: saveChanges)
            }
            .navigationTitle("Edit Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                title = song.title ?? ""
                composer = song.composer ?? ""
                songStatus = song.songStatus
                pieceType = song.pieceType
                goalPlays = "\(song.goalPlays)"
                selectedSuzukiBook = song.suzukiBook
            }
        }
    }

    private func saveChanges() {
        song.title = title
        song.composer = composer
        song.songStatus = songStatus
        song.pieceType = pieceType
        song.suzukiBook = selectedSuzukiBook
        song.goalPlays = Int64(goalPlays) ?? 0
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to save song changes: \(error)")
        }
    }
}
