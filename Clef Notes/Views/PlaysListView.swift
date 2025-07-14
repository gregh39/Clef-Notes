import Foundation
import SwiftUI
import SwiftData

struct PlaysListView: View {
    let groupedPlays: [(key: PracticeSession?, value: [Play])]
    
    @Environment(\.modelContext) private var context
    @State private var playToEdit: Play?

    var body: some View {
        List {
            ForEach(groupedPlays, id: \.key?.persistentModelID) { session, plays in
                Section(header: Text(session?.day.formatted(date: .abbreviated, time: .omitted) ?? "Unknown Session")) {
                    ForEach(plays) { play in
                        // --- THIS IS THE FIX ---
                        // Pass the cumulative total, which is efficiently looked up
                        // from the song's pre-calculated dictionary.
                        PlayRow(
                            play: play,
                            cumulativeTotal: play.song?.cumulativeTotalsByType[play] ?? play.count
                        )
                    }
                    .onDelete { indexSet in
                        deletePlay(at: indexSet, from: plays)
                    }
                }
            }
        }
        .sheet(item: $playToEdit) { play in
            PlayEditSheet(play: play)
        }
    }
    
    private func deletePlay(at offsets: IndexSet, from plays: [Play]) {
        for offset in offsets {
            let playToDelete = plays[offset]
            context.delete(playToDelete)
        }

        do {
            try context.save()
        } catch {
            print("Error saving context after deletion: \(error)")
        }
    }
}
