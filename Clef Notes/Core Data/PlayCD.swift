//
//  PlayCD+CoreDataClass.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//
//

import Foundation
import CoreData

@objc(PlayCD)
public class PlayCD: NSManagedObject {

}

extension PlayCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayCD> {
        return NSFetchRequest<PlayCD>(entityName: "PlayCD")
    }

    @NSManaged public var count: Int64
    @NSManaged public var playTypeRaw: String?
    @NSManaged public var session: PracticeSessionCD?
    @NSManaged public var song: SongCD?
    @NSManaged public var student: StudentCD?

    
    public var playType: PlayType? {
        get {
            guard let rawValue = playTypeRaw else { return nil }
            return PlayType(rawValue: rawValue)
        }
        set {
            playTypeRaw = newValue?.rawValue
        }
    }
    
    public var totalPlaysIncludingThis: Int {
        // Ensure the play belongs to a song that has a list of plays.
        guard let song = self.song else {
            return Int(self.count)
        }
        
        let allPlays = song.playsArray
        
        // 1. Sort all of the song's plays chronologically.
        let sortedPlays = allPlays.sorted {
            ($0.session?.day ?? .distantPast) < ($1.session?.day ?? .distantPast)
        }
        
        // 2. Find the position (index) of the current play (`self`) in the sorted list.
        guard let currentIndex = sortedPlays.firstIndex(of: self) else {
            return Int(self.count)
        }
        
        // 3. Get all the plays that appear *before* the current one in the sorted list.
        let precedingPlays = sortedPlays.prefix(upTo: currentIndex)
        
        // 4. Sum the 'count' of all those preceding plays.
        let previousTotal = precedingPlays.reduce(0) { $0 + Int($1.count) }
        
        // 5. Add the current play's own count to the subtotal.
        return previousTotal + Int(self.count)
    }

}

extension PlayCD : Identifiable {

}
