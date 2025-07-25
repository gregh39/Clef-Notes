// Clef Notes/Core Data Views/EditSongSheetCD.swift

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
            .onAppear {
                title = song.title ?? ""
                // --- THIS IS THE FIX: Populate composer state ---
                composer = song.composer ?? ""
                songStatus = song.songStatus
                pieceType = song.pieceType
            }
        }
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
