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