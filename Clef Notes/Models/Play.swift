//
//  Play.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/12/25.
//
import Foundation
import SwiftData

@Model
final class Play {
    @Relationship var session: PracticeSession?
    @Relationship var song: Song?
    var count: Int = 0
    
    init(count: Int) {
        self.count = count
    }
    
    var totalPlaysIncludingThis: Int {
        guard let song else {
            return count
        }

        let defaultDate = Calendar.current.date(from: DateComponents(year: 1901, month: 1, day: 1))!
        let sessionDate = session?.day ?? defaultDate

        let previousPlays = song.plays.filter {
            let playDate = $0.session?.day ?? defaultDate
            return playDate < sessionDate
        }

        let previousTotal = previousPlays.reduce(0) { $0 + $1.count }
        return previousTotal + count
    }
}
