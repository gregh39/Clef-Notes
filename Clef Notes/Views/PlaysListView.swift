//
//  PlaysListView.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/1/25.
//

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
                    ForEach(plays, id: \.persistentModelID) { play in
                        Button {
                            playToEdit = play
                        } label: {
                            // --- MODIFIED: Use the PlayRow component ---
                            // The cumulative total is looked up efficiently from the song's pre-calculated dictionary.
                            PlayRow(
                                play: play,
                                cumulativeTotal: play.song?.cumulativeTotalsByType[play] ?? play.count
                            )
                        }
                        .foregroundStyle(.primary) // Ensures the row is tappable and styled correctly
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
    
    /// Finds the correct Play object from the swipe offset and deletes it.
    private func deletePlay(at offsets: IndexSet, from plays: [Play]) {
        for offset in offsets {
            let playToDelete = plays[offset]
            context.delete(playToDelete)
        }

        // It's good practice to save the context after deletion.
        do {
            try context.save()
        } catch {
            print("Error saving context after deletion: \(error)")
        }
    }
}
// MARK: - Preview Helpers

struct MockPracticeSession: Identifiable, Hashable {
    let id = UUID()
    let day: Date
}

struct MockPlay: Identifiable, Hashable {
    let id = UUID()
    let count: Int
    let totalPlaysIncludingThis: Int
}

extension PracticeSession {
    static let preview = PracticeSession(day: Date(), durationMinutes: 45, studentID: UUID())
}

extension Play {
    static let preview = Play(count: 3)
}

#Preview {
    struct PreviewWrapper: View {
        @State var playToEdit: Play? = nil
        @State var showingPlayEditSheet = false
        var body: some View {
            PlaysListView(
                groupedPlays: [
                    (key: PracticeSession.preview, value: [Play.preview, Play(count: 2)])
                ]
            )
        }
    }
    return PreviewWrapper()
}

