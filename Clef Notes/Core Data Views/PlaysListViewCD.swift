import SwiftUI
import CoreData

struct PlaysListViewCD: View {
    // The view now uses the ViewModel as its source of data.
    @StateObject private var viewModel: PlaysListViewModel
    
    @Environment(\.managedObjectContext) private var context
    @State private var playToEdit: PlayCD?
    private let song: SongCD

    // The initializer creates the ViewModel, passing it the song and the context.
    init(song: SongCD, context: NSManagedObjectContext) {
        self.song = song
        _viewModel = StateObject(wrappedValue: PlaysListViewModel(song: song, context: context))
    }

    var body: some View {
        List {
            // The view now iterates over the data published by the ViewModel.
            ForEach(viewModel.groupedPlays, id: \.key?.objectID) { session, playsInSession in
                Section(header: Text(session?.day?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown Session")) {
                    ForEach(playsInSession) { play in
                        PlayRowCD(play: play, song: song) // Pass song explicitly.
                            .swipeActions(edge: .leading) {
                                Button {
                                    playToEdit = play
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                    .onDelete { indexSet in
                        deletePlay(at: indexSet, from: playsInSession)
                    }
                }
            }
        }
        .sheet(item: $playToEdit) { play in
            PlayEditSheetCD(play: play)
        }
    }
    
    private func deletePlay(at offsets: IndexSet, from playsInSession: [PlayCD]) {
        for offset in offsets {
            let playToDelete = playsInSession[offset]
            context.delete(playToDelete)
        }
        try? context.save()
    }
}

// PlayRowCD does not need to be changed. Its save action will trigger the
// notification that the new ViewModel is listening for.
struct PlayRowCD: View {
    @ObservedObject var play: PlayCD
    @ObservedObject var song: SongCD
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title ?? "Unknown Song")
                    .fontWeight(.medium)
                
                Text("Total \(play.playType?.rawValue ?? "") Plays: \(song.cumulativeCount(for: play))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    if play.count > 1 {
                        play.count -= 1
                        try? viewContext.save()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .font(.title2)
                .disabled(play.count <= 1)
                
                Text("\(play.count)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .frame(minWidth: 25)

                Button {
                    play.count += 1
                    try? viewContext.save()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .font(.title2)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
