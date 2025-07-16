//
//  PracticeSessionCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//


//
//  PracticeSessionCD+CoreDataClass.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//
//

import Foundation
import CoreData

@objc(PracticeSessionCD)
public class PracticeSessionCD: NSManagedObject {

}

extension PracticeSessionCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PracticeSessionCD> {
        return NSFetchRequest<PracticeSessionCD>(entityName: "PracticeSessionCD")
    }

    @NSManaged public var day: Date?
    @NSManaged public var durationMinutes: Int64
    @NSManaged public var locationRaw: String?
    @NSManaged public var studentID: UUID?
    @NSManaged public var title: String?
    @NSManaged public var instructor: InstructorCD?
    @NSManaged public var notes: NSSet?
    @NSManaged public var plays: NSSet?
    @NSManaged public var recordings: NSSet?
    @NSManaged public var student: StudentCD?
    
    public var location: LessonLocation? {
        get {
            guard let rawValue = locationRaw else { return nil }
            return LessonLocation(rawValue: rawValue)
        }
        set {
            locationRaw = newValue?.rawValue
        }
    }
    
    public var notesArray: [NoteCD] {
        let set = notes as? Set<NoteCD> ?? []
        return set.sorted {
            // Assuming notes don't have a direct timestamp, sort by text or another attribute if needed
            $0.text ?? "" < $1.text ?? ""
        }
    }

    public var playsArray: [PlayCD] {
        let set = plays as? Set<PlayCD> ?? []
        return set.sorted {
            // Assuming plays don't have a direct timestamp, sort by count or another attribute
            $0.count > $1.count
        }
    }

    public var recordingsArray: [AudioRecordingCD] {
        let set = recordings as? Set<AudioRecordingCD> ?? []
        return set.sorted {
            $0.dateRecorded ?? .distantPast > $1.dateRecorded ?? .distantPast
        }
    }

}

// MARK: Generated accessors for notes
extension PracticeSessionCD {

    @objc(addNotesObject:)
    @NSManaged public func addToNotes(_ value: NoteCD)

    @objc(removeNotesObject:)
    @NSManaged public func removeFromNotes(_ value: NoteCD)

    @objc(addNotes:)
    @NSManaged public func addToNotes(_ values: NSSet)

    @objc(removeNotes:)
    @NSManaged public func removeFromNotes(_ values: NSSet)

}

// MARK: Generated accessors for plays
extension PracticeSessionCD {

    @objc(addPlaysObject:)
    @NSManaged public func addToPlays(_ value: PlayCD)

    @objc(removePlaysObject:)
    @NSManaged public func removeFromPlays(_ value: PlayCD)

    @objc(addPlays:)
    @NSManaged public func addToPlays(_ values: NSSet)

    @objc(removePlays:)
    @NSManaged public func removeFromPlays(_ values: NSSet)

}

// MARK: Generated accessors for recordings
extension PracticeSessionCD {

    @objc(addRecordingsObject:)
    @NSManaged public func addToRecordings(_ value: AudioRecordingCD)

    @objc(removeRecordingsObject:)
    @NSManaged public func removeFromRecordings(_ value: AudioRecordingCD)

    @objc(addRecordings:)
    @NSManaged public func addToRecordings(_ values: NSSet)

    @objc(removeRecordings:)
    @NSManaged public func removeFromRecordings(_ values: NSSet)

}

extension PracticeSessionCD : Identifiable {

}
