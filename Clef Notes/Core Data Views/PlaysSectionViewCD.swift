import SwiftUI
import CoreData
import Combine
import TelemetryDeck

@MainActor
class PlaysSectionViewModel: ObservableObject {
    @Published var plays: [PlayCD] = []
    private var cancellables = Set<AnyCancellable>()

    init(session: PracticeSessionCD, context: NSManagedObjectContext) {
        fetchPlays(session: session, context: context)
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: context)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchPlays(session: session, context: context)
            }
            .store(in: &cancellables)
    }

    private func fetchPlays(session: PracticeSessionCD, context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<PlayCD> = PlayCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "session == %@", session)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PlayCD.song?.title, ascending: true)]
        do {
            plays = try context.fetch(fetchRequest)
        } catch {
            plays = []
        }
    }
}

struct PlaysSectionViewCD: View {
    @StateObject private var viewModel: PlaysSectionViewModel
    
    @Binding var showingAddPlaySheet: Bool
    @Binding var playToEdit: PlayCD?
    @Environment(\.managedObjectContext) private var viewContext

    // The initializer now configures the ViewModel based on the session and context
    init(session: PracticeSessionCD, showingAddPlaySheet: Binding<Bool>, playToEdit: Binding<PlayCD?>, context: NSManagedObjectContext) {
        self._showingAddPlaySheet = showingAddPlaySheet
        self._playToEdit = playToEdit
        _viewModel = StateObject(wrappedValue: PlaysSectionViewModel(session: session, context: context))
    }

    var body: some View {
        Section("Session Plays") {
            if viewModel.plays.isEmpty {
                Button(action: {
                    TelemetryDeck.signal("play_created")
                    showingAddPlaySheet = true
                }) {
                    Label("Add Play", systemImage: "music.note.list")
                        .padding()
                        .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(viewModel.plays) { play in
                    // Pass the song explicitly to match PlayRowCD signature
                    PlayRowCD(play: play, song: play.song!)
                        .swipeActions(edge: .leading) {
                            Button {
                                playToEdit = play
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                }
                .onDelete(perform: deletePlay)
                
                Button(action: {
                    TelemetryDeck.signal("play_created")
                    showingAddPlaySheet = true
                }) {
                    Label("Add Another Play", systemImage: "plus")
                }
            }
        }
    }
    
    private func deletePlay(at offsets: IndexSet) {
        for index in offsets {
            let playToDelete = viewModel.plays[index]
            viewContext.delete(playToDelete)
        }
        try? viewContext.save()
        TelemetryDeck.signal("play_deleted")
    }
}

/*struct PlayRowCD: View {
    @ObservedObject var play: PlayCD
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(play.song?.title ?? "Unknown Song")
                    .fontWeight(.medium)
                
                // --- CHANGE 2: Call the new calculation method ---
                Text("Total \(play.playType?.rawValue ?? "") Plays: \(play.song?.cumulativeCount(for: play) ?? Int(play.count))")
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
*/
