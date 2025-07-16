//
//  AudioRecordingCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//


//
//  AudioRecordingCD+CoreDataClass.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//
//

import Foundation
import CoreData

@objc(AudioRecordingCD)
public class AudioRecordingCD: NSManagedObject {

}

extension AudioRecordingCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AudioRecordingCD> {
        return NSFetchRequest<AudioRecordingCD>(entityName: "AudioRecordingCD")
    }

    @NSManaged public var data: Data?
    @NSManaged public var dateRecorded: Date?
    @NSManaged public var duration: Double
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var session: PracticeSessionCD?
    @NSManaged public var songs: NSSet?
    
    public var songsArray: [SongCD] {
        let set = songs as? Set<SongCD> ?? []
        return set.sorted {
            $0.title ?? "" < $1.title ?? ""
        }
    }

}

// MARK: Generated accessors for songs
extension AudioRecordingCD {

    @objc(addSongsObject:)
    @NSManaged public func addToSongs(_ value: SongCD)

    @objc(removeSongsObject:)
    @NSManaged public func removeFromSongs(_ value: SongCD)

    @objc(addSongs:)
    @NSManaged public func addToSongs(_ values: NSSet)

    @objc(removeSongs:)
    @NSManaged public func removeFromSongs(_ values: NSSet)

}

extension AudioRecordingCD : Identifiable {

}
