//
//  CollectionCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 12/17/25.
//


import Foundation
import CoreData

@objc(CollectionCD)
public class CollectionCD: NSManagedObject {
}

extension CollectionCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CollectionCD> {
        return NSFetchRequest<CollectionCD>(entityName: "CollectionCD")
    }

    @NSManaged public var name: String?                 // Free-form tag/name
    @NSManaged public var songs: NSSet?                 // One collection can have many songs
    /// Added in model v5. Each collection belongs to one student so it shares that student's
    /// CloudKit zone. Collections created before v5 may have no student.
    @NSManaged public var student: StudentCD?
}

// MARK: Generated accessors for songs
extension CollectionCD {
    @objc(addSongsObject:)
    @NSManaged public func addToSongs(_ value: SongCD)

    @objc(removeSongsObject:)
    @NSManaged public func removeFromSongs(_ value: SongCD)

    @objc(addSongs:)
    @NSManaged public func addToSongs(_ values: NSSet)

    @objc(removeSongs:)
    @NSManaged public func removeFromSongs(_ values: NSSet)
}

extension CollectionCD: Identifiable {}

extension CollectionCD {
    /// Creates a collection owned by `student`, in the student's persistent store.
    ///
    /// The student link is what puts the collection in the same CloudKit zone as the student's
    /// songs. A collection saved without it lands in the private database's default zone, and
    /// linking a shared student's songs to it stops sync ("assigned to multiple zones").
    static func create(named name: String, for student: StudentCD, in context: NSManagedObjectContext) -> CollectionCD {
        let collection = CollectionCD(context: context)
        collection.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        collection.student = student
        if let store = student.objectID.persistentStore {
            context.assign(collection, to: store)
        }
        return collection
    }

    /// Gives collections from before model v5 an owner when all their songs belong to one student,
    /// so they still show up in that student's collection picker. Collections that are empty or
    /// mix students are left alone and can be removed from Settings → Manage Collections.
    static func assignOwnersToLegacyCollections(in context: NSManagedObjectContext) {
        context.perform {
            let request = CollectionCD.fetchRequest()
            request.predicate = NSPredicate(format: "student == nil")
            guard let collections = try? context.fetch(request), !collections.isEmpty else { return }

            for collection in collections {
                let owners = Set((collection.songs as? Set<SongCD> ?? []).compactMap(\.student))
                if owners.count == 1 {
                    collection.student = owners.first
                }
            }

            guard context.hasChanges else { return }
            do {
                try context.save()
            } catch {
                print("Failed to assign owners to legacy collections: \(error)")
                context.rollback()
            }
        }
    }
}