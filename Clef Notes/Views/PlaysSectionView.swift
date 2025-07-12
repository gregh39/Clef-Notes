//
//  PlaysSectionView.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/13/25.
//
import SwiftUI
import SwiftData

struct PlaysSectionView: View {
    @Bindable var session: PracticeSession
    
    @Binding var showingAddPlaySheet: Bool
    @Binding var showingAddSongSheet: Bool
    @Binding var playToEdit: Play?
    
    @Environment(\.modelContext) private var context
    
    // The query is not directly used in this view's body but might be needed for the addPlaySheet.
    // Kept for context.
    @Query(sort: \Song.title) private var songs: [Song]

    var body: some View {
        Section("Session Plays") {
            // Use a computed property for cleaner access and handling of optional array.
            let plays = session.plays ?? []
            
            if plays.isEmpty {
                // An improved empty state view that's more centered and inviting.
                Button(action: { showingAddPlaySheet = true }) {
                    Label("Add Play", systemImage: "music.note.list")
                        .padding()
                        .frame(maxWidth: .infinity)
                }
            } else {
                // Loop over the existing plays.
                ForEach(plays) { play in
                    Button(action: { playToEdit = play }) {
                        PlayRow(play: play)
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete(perform: deletePlay) // Abstracted the delete logic to a separate function.
                
                // A single, clean button at the end of the list to add more plays.
                Button(action: { showingAddPlaySheet = true }) {
                    Label("Add Another Play", systemImage: "plus")
                }
            }
        }
    }
    
    
    
    /// Handles the deletion of plays from the list and the model context.
    private func deletePlay(at offsets: IndexSet) {
        for index in offsets {
            guard let play = session.plays?[index] else { continue }
            context.delete(play)
            session.plays?.remove(at: index)
        }
        // It's good practice to wrap the save in a do-catch block.
        do {
            try context.save()
        } catch {
            // Handle the save error, e.g., by logging it.
            print("Failed to save context after deletion: \(error)")
        }
    }
}

