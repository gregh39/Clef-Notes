import Foundation
import CoreData
import Combine

class UsageManager: ObservableObject {
    private let viewContext: NSManagedObjectContext
    private var tracker: UsageTrackerCD

    init(context: NSManagedObjectContext) {
        self.viewContext = context

        let fetchRequest: NSFetchRequest<UsageTrackerCD> = UsageTrackerCD.fetchRequest()
        let trackers = (try? context.fetch(fetchRequest)) ?? []
        if let firstTracker = trackers.first {
            self.tracker = firstTracker
        } else {
            let newTracker = UsageTrackerCD(context: context)
            newTracker.totalStudentsCreated = 0
            newTracker.totalSessionsCreated = 0
            newTracker.totalSongsCreated = 0
            newTracker.totalMetronomeOpens = 0
            newTracker.totalTunerOpens = 0
            self.tracker = newTracker
            try? context.save()
        }
    }

    // MARK: - Global Creation Counts
    var studentCreations: Int { Int(tracker.totalStudentsCreated) }
    var sessionCreations: Int { Int(tracker.totalSessionsCreated) }
    var songCreations: Int { Int(tracker.totalSongsCreated) }
    var metronomeOpens: Int { Int(tracker.totalMetronomeOpens) }
    var tunerOpens: Int { Int(tracker.totalTunerOpens) }

    // MARK: - Increment Methods
    func incrementStudentCreations() {
        tracker.totalStudentsCreated += 1
        try? viewContext.save()
    }

    func incrementSessionCreations() {
        tracker.totalSessionsCreated += 1
        try? viewContext.save()
    }

    func incrementSongCreations() {
        tracker.totalSongsCreated += 1
        try? viewContext.save()
    }

    func incrementMetronomeOpens() {
        tracker.totalMetronomeOpens += 1
        try? viewContext.save()
    }

    func incrementTunerOpens() {
        tracker.totalTunerOpens += 1
        try? viewContext.save()
    }

    /// Cleans up duplicate UsageTrackerCD entries, keeping only the one with the highest total count.
    /// Should be run once on startup.
    static func cleanupDuplicateTrackersIfNeeded(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<UsageTrackerCD> = UsageTrackerCD.fetchRequest()
        let trackers = (try? context.fetch(fetchRequest)) ?? []
        if let trackerToKeep = trackers.max(by: { ($0.totalStudentsCreated + $0.totalSessionsCreated + $0.totalSongsCreated) < ($1.totalStudentsCreated + $1.totalSessionsCreated + $1.totalSongsCreated) }) {
            for t in trackers where t != trackerToKeep {
                context.delete(t)
            }
            if trackers.count > 1 {
                try? context.save()
            }
        }
    }
}
