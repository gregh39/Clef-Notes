//
//  Play.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/12/25.
//
import SwiftData

@Model
final class Play {
    @Relationship var session: PracticeSession?
    @Relationship var song: Song?
    var count: Int
    
    init(count: Int) {
        self.count = count
    }
}
