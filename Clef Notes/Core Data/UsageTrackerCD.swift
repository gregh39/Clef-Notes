//
//  UsageTrackerCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/25/25.
//


import Foundation
import CoreData

@objc(UsageTrackerCD)
public class UsageTrackerCD: NSManagedObject {

}

extension UsageTrackerCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UsageTrackerCD> {
        return NSFetchRequest<UsageTrackerCD>(entityName: "UsageTrackerCD")
    }

    @NSManaged public var totalStudentsCreated: Int64
    @NSManaged public var totalSessionsCreated: Int64 // Add this
    @NSManaged public var totalSongsCreated: Int64   // Add this
    @NSManaged public var totalMetronomeOpens: Int64
    @NSManaged public var totalTunerOpens: Int64

}

extension UsageTrackerCD : Identifiable {

}

