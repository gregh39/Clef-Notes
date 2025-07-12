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
    
    @Query(sort: \Song.title) private var songs: [Song]

    var body: some View {
        Section("Session Plays") {
            let plays = session.plays ?? []
            
            if plays.isEmpty {
                Button(action: { showingAddPlaySheet = true }) {
                    Label("Add Play", systemImage: "music.note.list")
                        .padding()
                        .frame(maxWidth: .infinity)
                }
            } else {
                // --- MODIFIED: Calculate totals once before the loop ---
                let totalsByPlay = plays.reduce(into: [Play: Int]()) { result, play in
                    if let songTotals = play.song?.cumulativeTotalsByType {
                        result[play] = songTotals[play]
                    }
                }

                ForEach(plays) { play in
                    Button(action: { playToEdit = play }) {
                        // Pass the pre-calculated total into the row view.
                        PlayRow(play: play, cumulativeTotal: totalsByPlay[play] ?? play.count)
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete(perform: deletePlay)
                
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

