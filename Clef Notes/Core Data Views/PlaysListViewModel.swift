import Foundation
import CoreData
import Combine

@MainActor
class PlaysListViewModel: ObservableObject {
    // The view will observe this property for changes.
    @Published var groupedPlays: [(key: PracticeSessionCD?, value: [PlayCD])] = []
    
    private let song: SongCD
    private var cancellables = Set<AnyCancellable>()

    init(song: SongCD, context: NSManagedObjectContext) {
        self.song = song
        
        // Load the data initially.
        fetchAndGroupPlays()
        
        // Use Combine to listen for the notification that Core Data broadcasts
        // whenever a save operation completes successfully.
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: context)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // When a save is detected, re-fetch and re-group the data.
                self?.fetchAndGroupPlays()
            }
            .store(in: &cancellables)
    }
    
    /// This function fetches the latest 'plays' from the persistent store
    /// and updates the @Published 'groupedPlays' property, causing the UI to refresh.
    func fetchAndGroupPlays() {
        let plays = song.plays as? Set<PlayCD> ?? []
        let sortedPlays = plays.sorted { ($0.session?.day ?? .distantPast) > ($1.session?.day ?? .distantPast) }
        
        let grouped = Dictionary(grouping: sortedPlays, by: { $0.session })
        self.groupedPlays = grouped.sorted { ($0.key?.day ?? .distantPast) > ($1.key?.day ?? .distantPast) }
    }
}
