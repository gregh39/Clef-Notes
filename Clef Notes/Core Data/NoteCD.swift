//
//  NoteCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//


//
//  NoteCD+CoreDataClass.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//
//

import Foundation
import CoreData

@objc(NoteCD)
public class NoteCD: NSManagedObject {

}

extension NoteCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NoteCD> {
        return NSFetchRequest<NoteCD>(entityName: "NoteCD")
    }

    @NSManaged public var drawing: Data?
    @NSManaged public var text: String?
    @NSManaged public var title: String?
    @NSManaged public var date: Date?
    @NSManaged public var session: PracticeSessionCD?
    @NSManaged public var songs: NSSet?
    @NSManaged public var student: StudentCD?

    
    public var songsArray: [SongCD] {
        let set = songs as? Set<SongCD> ?? []
        return set.sorted {
            $0.title ?? "" < $1.title ?? ""
        }
    }

}

// MARK: Generated accessors for songs
extension NoteCD {

    @objc(addSongsObject:)
    @NSManaged public func addToSongs(_ value: SongCD)

    @objc(removeSongsObject:)
    @NSManaged public func removeFromSongs(_ value: SongCD)

    @objc(addSongs:)
    @NSManaged public func addToSongs(_ values: NSSet)

    @objc(removeSongs:)
    @NSManaged public func removeFromSongs(_ values: NSSet)

}

extension NoteCD : Identifiable {

}
