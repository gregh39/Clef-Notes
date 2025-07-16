//
//  Play.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/12/25.
//
import Foundation
import SwiftData

public enum PlayType: String, Codable, CaseIterable {
    case learning = "Learning"
    case practice = "Practice"
    case review = "Review"
}

@Model
final class Play {
    @Relationship var session: PracticeSession?
    @Relationship var song: Song?
    var count: Int = 0
    var playType: PlayType?
    
    init(count: Int) {
        self.count = count
    }
    
    var totalPlaysIncludingThis: Int {
        // Ensure the play belongs to a song that has a list of plays.
        guard let song = self.song, let allPlays = song.plays else {
            return self.count
        }
        
        // 1. Sort all of the song's plays chronologically.
        //    Using a secondary sort key like a timestamp would be more robust,
        //    but sorting by date is sufficient if the original array order is consistent.
        let sortedPlays = allPlays.sorted {
            // Use distantPast to handle plays that might not have a session date.
            ($0.session?.day ?? .distantPast) < ($1.session?.day ?? .distantPast)
        }
        
        // 2. Find the position (index) of the current play (`self`) in the sorted list.
        guard let currentIndex = sortedPlays.firstIndex(of: self) else {
            // This should not happen, but it's safe to have a fallback.
            return self.count
        }
        
        // 3. Get all the plays that appear *before* the current one in the sorted list.
        let precedingPlays = sortedPlays.prefix(upTo: currentIndex)
        
        // 4. Sum the 'count' of all those preceding plays.
        let previousTotal = precedingPlays.reduce(0) { $0 + $1.count }
        
        // 5. Add the current play's own count to the subtotal.
        return previousTotal + self.count
    }
}

