//
//  MediaReferenceCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//


//
//  MediaReferenceCD+CoreDataClass.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//
//

import Foundation
import CoreData

@objc(MediaReferenceCD)
public class MediaReferenceCD: NSManagedObject {

}

extension MediaReferenceCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MediaReferenceCD> {
        return NSFetchRequest<MediaReferenceCD>(entityName: "MediaReferenceCD")
    }

    @NSManaged public var data: Data?
    @NSManaged public var duration: Double
    @NSManaged public var notes: String?
    @NSManaged public var title: String?
    @NSManaged public var typeRaw: String?
    @NSManaged public var url: URL?
    @NSManaged public var song: SongCD?
    @NSManaged public var student: StudentCD?

    
    public var type: MediaType? {
        get {
            guard let rawValue = typeRaw else { return nil }
            return MediaType(rawValue: rawValue)
        }
        set {
            typeRaw = newValue?.rawValue
        }
    }

}

extension MediaReferenceCD : Identifiable {

}
