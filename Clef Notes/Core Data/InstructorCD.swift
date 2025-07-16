//
//  InstructorCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//


//
//  InstructorCD+CoreDataClass.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//
//

import Foundation
import CoreData

@objc(InstructorCD)
public class InstructorCD: NSManagedObject {

}

extension InstructorCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<InstructorCD> {
        return NSFetchRequest<InstructorCD>(entityName: "InstructorCD")
    }

    @NSManaged public var name: String?
    @NSManaged public var sessions: NSSet?
    
    public var sessionsArray: [PracticeSessionCD] {
        let set = sessions as? Set<PracticeSessionCD> ?? []
        return set.sorted {
            $0.day ?? .distantPast > $1.day ?? .distantPast
        }
    }

}

// MARK: Generated accessors for sessions
extension InstructorCD {

    @objc(addSessionsObject:)
    @NSManaged public func addToSessions(_ value: PracticeSessionCD)

    @objc(removeSessionsObject:)
    @NSManaged public func removeFromSessions(_ value: PracticeSessionCD)

    @objc(addSessions:)
    @NSManaged public func addToSessions(_ values: NSSet)

    @objc(removeSessions:)
    @NSManaged public func removeFromSessions(_ values: NSSet)

}

extension InstructorCD : Identifiable {

}
