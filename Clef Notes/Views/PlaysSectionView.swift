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
                ForEach(plays) { play in
                    // The "Edit" button functionality is now on a long press or separate button if needed.
                    // For now, the row is interactive for counting.
                    PlayRow(
                        play: play,
                        // --- THIS IS THE FIX ---
                        // Pass the pre-calculated cumulative total for this play.
                        cumulativeTotal: play.song?.cumulativeTotalsByType[play] ?? play.count
                    )
                }
                .onDelete(perform: deletePlay)
                
                Button(action: { showingAddPlaySheet = true }) {
                    Label("Add Another Play", systemImage: "plus")
                }
            }
        }
    }
    
    private func deletePlay(at offsets: IndexSet) {
        // Ensure we're deleting from the correct, sorted array if necessary.
        // For now, assuming session.plays order is stable for this view.
        var playsToDelete: [Play] = []
        for index in offsets {
            if let play = session.plays?[index] {
                playsToDelete.append(play)
            }
        }
        
        for play in playsToDelete {
            context.delete(play)
        }
        
        session.plays?.remove(atOffsets: offsets)
        
        try? context.save()
    }
}
