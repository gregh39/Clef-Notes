//
//  SongCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//


//
//  SongCD+CoreDataClass.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//
//

import Foundation
import CoreData
import Combine

@objc(SongCD)
public class SongCD: NSManagedObject {

    private var cancellables = Set<AnyCancellable>()

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        observeContext()
    }

    public override func awakeFromFetch() {
        super.awakeFromFetch()
        observeContext()
    }

    private func observeContext() {
        guard let moc = self.managedObjectContext else { return }
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: moc)
            .sink { [weak self] notification in
                guard let self = self else { return }
                // Check if any changed PlayCDs relate to this song
                if let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>,
                   updated.contains(where: { ($0 as? PlayCD)?.song == self }) {
                    self.objectWillChange.send()
                }
                if let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>,
                   inserted.contains(where: { ($0 as? PlayCD)?.song == self }) {
                    self.objectWillChange.send()
                }
                if let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>,
                   deleted.contains(where: { ($0 as? PlayCD)?.song == self }) {
                    self.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

}

extension SongCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SongCD> {
        return NSFetchRequest<SongCD>(entityName: "SongCD")
    }

    @NSManaged public var composer: String?
    @NSManaged public var goalPlays: Int64
    @NSManaged public var pieceTypeRaw: String?
    @NSManaged public var songStatusRaw: String?
    @NSManaged public var suzukiBookRaw: String?
    @NSManaged public var studentID: UUID?
    @NSManaged public var title: String?
    @NSManaged public var media: NSSet?
    @NSManaged public var notes: NSSet?
    @NSManaged public var plays: NSSet?
    @NSManaged public var recordings: NSSet?
    @NSManaged public var student: StudentCD?
    
    public var pieceType: PieceType? {
        get {
            guard let rawValue = pieceTypeRaw else { return nil }
            return PieceType(rawValue: rawValue)
        }
        set {
            pieceTypeRaw = newValue?.rawValue
        }
    }
    
    public var suzukiBook: SuzukiBook? {
        get {
            guard let suzukiBook = self.suzukiBookRaw else { return nil }
            return SuzukiBook(rawValue: suzukiBook)
        }
        set {
            self.suzukiBookRaw = newValue?.rawValue
        }
    }

    
    public var songStatus: PlayType? {
        get {
            guard let rawValue = songStatusRaw else { return nil }
            return PlayType(rawValue: rawValue)
        }
        set {
            songStatusRaw = newValue?.rawValue
        }
    }
    
    public var mediaArray: [MediaReferenceCD] {
        let set = media as? Set<MediaReferenceCD> ?? []
        return set.sorted {
            ($0.title ?? "") < ($1.title ?? "")
        }
    }
    
    public var notesArray: [NoteCD] {
        let set = notes as? Set<NoteCD> ?? []
        return set.sorted {
            ($0.session?.day ?? .distantPast) > ($1.session?.day ?? .distantPast)
        }
    }
    
    public var playsArray: [PlayCD] {
        let set = plays as? Set<PlayCD> ?? []
        return set.sorted {
            ($0.session?.day ?? .distantPast) > ($1.session?.day ?? .distantPast)
        }
    }
    
    public var recordingsArray: [AudioRecordingCD] {
        let set = recordings as? Set<AudioRecordingCD> ?? []
        return set.sorted {
            $0.dateRecorded ?? .distantPast > $1.dateRecorded ?? .distantPast
        }
    }
    
    // MARK: - Computed Properties -
    
    public var totalPlayCount: Int {
        playsArray.reduce(0) { $0 + Int($1.count) }
    }

    public var totalGoalPlayCount: Int {
        playsArray.filter { $0.playType == .practice }.reduce(0) { $0 + Int($1.count) }
    }

    public var lastPlayedDate: Date? {
        playsArray.compactMap { $0.session?.day }.max()
    }
    
    public func cumulativeCount(for play: PlayCD) -> Int {
        guard let type = play.playType else { return Int(play.count) }
        
        // Filter plays of the same type and sort them chronologically.
        let relevantPlays = self.playsArray.filter { $0.playType == type }.sorted {
            ($0.session?.day ?? .distantPast) < ($1.session?.day ?? .distantPast)
        }
        
        // Find the index of the current play.
        guard let currentIndex = relevantPlays.firstIndex(of: play) else {
            return Int(play.count)
        }
        
        // Sum the counts of all plays up to and including the current one.
        let total = relevantPlays.prefix(through: currentIndex).reduce(0) { $0 + Int($1.count) }
        return total
    }

}

// MARK: Generated accessors for media
extension SongCD {

    @objc(addMediaObject:)
    @NSManaged public func addToMedia(_ value: MediaReferenceCD)

    @objc(removeMediaObject:)
    @NSManaged public func removeFromMedia(_ value: MediaReferenceCD)

    @objc(addMedia:)
    @NSManaged public func addToMedia(_ values: NSSet)

    @objc(removeMedia:)
    @NSManaged public func removeFromMedia(_ values: NSSet)

}

// MARK: Generated accessors for notes
extension SongCD {

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
extension SongCD {

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
extension SongCD {

    @objc(addRecordingsObject:)
    @NSManaged public func addToRecordings(_ value: AudioRecordingCD)

    @objc(removeRecordingsObject:)
    @NSManaged public func removeFromRecordings(_ value: AudioRecordingCD)

    @objc(addRecordings:)
    @NSManaged public func addToRecordings(_ values: NSSet)

    @objc(removeRecordings:)
    @NSManaged public func removeFromRecordings(_ values: NSSet)

}

extension SongCD : Identifiable {

}
