//
//  StudentCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//


import Foundation
import CoreData

@objc(StudentCD)
public class StudentCD: NSManagedObject {

}

extension StudentCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StudentCD> {
        return NSFetchRequest<StudentCD>(entityName: "StudentCD")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var instrument: String?
    @NSManaged public var name: String?
    @NSManaged public var avatar: Data?
    @NSManaged public var sessions: NSSet?
    @NSManaged public var songs: NSSet?
    @NSManaged public var plays: NSSet?
    @NSManaged public var notes: NSSet?
    @NSManaged public var mediaReferences: NSSet?
    @NSManaged public var instructors: NSSet?
    @NSManaged public var audioRecordings: NSSet?
    
    public var instrumentType: Instrument? {
        get {
            guard let instrumentName = self.instrument else { return nil }
            return Instrument(rawValue: instrumentName)
        }
        set {
            self.instrument = newValue?.rawValue
        }
    }
    
    // --- THIS IS THE FIX: A new property to check if the object is shared ---
    public var isShared: Bool {
        guard let store = self.objectID.persistentStore else {
            return false
        }
        return store == PersistenceController.shared.sharedPersistentStore
    }
    
    public var songsArray: [SongCD] {
        let set = songs as? Set<SongCD> ?? []
        return set.sorted { (lhs: SongCD, rhs: SongCD) in
            lhs.title ?? "" < rhs.title ?? ""
        }
    }
    
    public var sessionsArray: [PracticeSessionCD] {
        let set = sessions as? Set<PracticeSessionCD> ?? []
        return set.sorted { (lhs: PracticeSessionCD, rhs: PracticeSessionCD) in
            lhs.day ?? .distantPast > rhs.day ?? .distantPast
        }
    }

}

// MARK: Generated accessors for sessions
extension StudentCD {

    @objc(addSessionsObject:)
    @NSManaged public func addToSessions(_ value: PracticeSessionCD)

    @objc(removeSessionsObject:)
    @NSManaged public func removeFromSessions(_ value: PracticeSessionCD)

    @objc(addSessions:)
    @NSManaged public func addToSessions(_ values: NSSet)

    @objc(removeSessions:)
    @NSManaged public func removeFromSessions(_ values: NSSet)

}

// MARK: Generated accessors for songs
extension StudentCD {

    @objc(addSongsObject:)
    @NSManaged public func addToSongs(_ value: SongCD)

    @objc(removeSongsObject:)
    @NSManaged public func removeFromSongs(_ value: SongCD)

    @objc(addSongs:)
    @NSManaged public func addToSongs(_ values: NSSet)

    @objc(removeSongs:)
    @NSManaged public func removeFromSongs(_ values: NSSet)

}

extension StudentCD : Identifiable {

}
