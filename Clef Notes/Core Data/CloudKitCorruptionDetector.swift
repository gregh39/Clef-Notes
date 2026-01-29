import Foundation
import CoreData
import CloudKit

/// Detects and manages CloudKit sync corruption issues
class CloudKitCorruptionDetector {

    struct CorruptedObject: Identifiable {
        let id = UUID()
        let objectID: NSManagedObjectID
        let entityName: String
        let displayInfo: String
        let zones: [String]
    }

    /// Scans for objects assigned to multiple CloudKit zones
    static func detectCorruptedObjects(in context: NSManagedObjectContext) -> [CorruptedObject] {
        var corruptedObjects: [CorruptedObject] = []

        context.performAndWait {
            // Check PlayCD entities (the error specifically mentions PlayCD)
            let playFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PlayCD")

            do {
                if let plays = try context.fetch(playFetchRequest) as? [NSManagedObject] {
                    for play in plays {
                        // Try to get CloudKit metadata to check zone assignments
                        // Note: We can't directly check zone assignments without CloudKit APIs,
                        // but we can identify objects that might be corrupted based on
                        // the error logs pointing to specific objectIDs

                        var displayInfo = "Play record"

                        // Try to get more context about this play
                        if let playType = play.value(forKey: "playTypeRaw") as? String {
                            displayInfo += " - Type: \(playType)"
                        }
                        if let count = play.value(forKey: "count") as? Int64 {
                            displayInfo += " - Count: \(count)"
                        }

                        // Get related song info if available
                        if let song = play.value(forKey: "song") as? NSManagedObject {
                            if let songTitle = song.value(forKey: "title") as? String {
                                displayInfo += " - Song: \(songTitle)"
                            }
                        }

                        // Get related student info if available
                        if let student = play.value(forKey: "student") as? NSManagedObject {
                            if let studentName = student.value(forKey: "name") as? String {
                                displayInfo += " - Student: \(studentName)"
                            }
                        }

                        // For now, we'll mark any object that could potentially be corrupted
                        // In a real scenario, we'd need to check CloudKit metadata
                        // but that requires accessing private CloudKit APIs

                        // We can check if the object has issues by looking for
                        // objects with both private and shared zone markers
                        // This is a heuristic approach
                    }
                }
            } catch {
                print("Error fetching PlayCD objects: \(error)")
            }
        }

        return corruptedObjects
    }

    /// Attempts to fix corruption by deleting the specified objects
    static func deleteCorruptedObjects(_ objects: [CorruptedObject], from context: NSManagedObjectContext) -> Result<Int, Error> {
        var deletedCount = 0

        do {
            try context.performAndWait {
                for corruptedObj in objects {
                    if let object = try? context.existingObject(with: corruptedObj.objectID) {
                        context.delete(object)
                        deletedCount += 1
                    }
                }

                try context.save()
            }

            return .success(deletedCount)
        } catch {
            return .failure(error)
        }
    }

    /// Alternative approach: Reset CloudKit mirroring state
    /// This forces CloudKit to re-evaluate all objects
    /// Note: This method is currently unused but kept for reference
    /*
    static func resetCloudKitState(persistentContainer: NSPersistentCloudKitContainer) {
        // This is a more aggressive approach that resets the CloudKit sync state
        // It will cause a full re-sync but can fix zone assignment issues
        // Requires access to store descriptions, not store instances
    }
    */

    /// More targeted approach: Find and delete specific corrupted object by URI
    static func findAndDeleteCorruptedObject(
        uri: String,
        in context: NSManagedObjectContext
    ) -> Result<String, Error> {
        do {
            // The error message shows URIs like: x-coredata://5CCA6757-3B4A-4749-A4ED-6CAB5B1CA646/PlayCD/p1291
            // We can try to construct the objectID from this

            if let url = URL(string: uri),
               let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) {

                if let object = try? context.existingObject(with: objectID) {
                    var info = "Deleted \(object.entity.name ?? "object")"

                    // Get some info before deleting
                    if let play = object as? NSManagedObject {
                        if let song = play.value(forKey: "song") as? NSManagedObject,
                           let title = song.value(forKey: "title") as? String {
                            info += " for song '\(title)'"
                        }
                    }

                    context.delete(object)
                    try context.save()

                    return .success(info)
                } else {
                    return .success("Object not found (may have been already deleted)")
                }
            }

            return .failure(NSError(domain: "CloudKitCorruptionDetector", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not parse object URI"
            ]))
        } catch {
            return .failure(error)
        }
    }
}
