import Foundation
import CoreData
import Combine

class UsageManager: ObservableObject {
    private let viewContext: NSManagedObjectContext
    private var tracker: UsageTrackerCD

    init(context: NSManagedObjectContext) {
        self.viewContext = context

        let fetchRequest: NSFetchRequest<UsageTrackerCD> = UsageTrackerCD.fetchRequest()
        if let existingTracker = try? context.fetch(fetchRequest).first {
            self.tracker = existingTracker
        } else {
            let newTracker = UsageTrackerCD(context: context)
            newTracker.totalStudentsCreated = 0
            newTracker.totalSessionsCreated = 0
            newTracker.totalSongsCreated = 0
            self.tracker = newTracker
            try? context.save()
        }
    }

    // MARK: - Global Creation Counts
    var studentCreations: Int { Int(tracker.totalStudentsCreated) }
    var sessionCreations: Int { Int(tracker.totalSessionsCreated) }
    var songCreations: Int { Int(tracker.totalSongsCreated) }

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
}
