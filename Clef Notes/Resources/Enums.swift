//
//  Enums.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/18/25.
//

// --- THIS IS THE FIX: A new, comprehensive enum for instruments ---

import SwiftUI
import Foundation
import CoreData

public enum Instrument: String, CaseIterable, Identifiable {
    public var id: String { self.rawValue }

    // Strings
    case violin = "Violin"
    case viola = "Viola"
    case cello = "Cello"
    case doubleBass = "Double Bass"
    case harp = "Harp"

    // Woodwinds
    case flute = "Flute"
    case piccolo = "Piccolo"
    case oboe = "Oboe"
    case englishHorn = "English Horn"
    case clarinet = "Clarinet"
    case bassClarinet = "Bass Clarinet"
    case bassoon = "Bassoon"
    case contrabassoon = "Contrabassoon"
    case saxophone = "Saxophone"

    // Brass
    case frenchHorn = "French Horn"
    case trumpet = "Trumpet"
    case trombone = "Trombone"
    case bassTrombone = "Bass Trombone"
    case tuba = "Tuba"
    
    // Keyboards
    case piano = "Piano"
    case organ = "Organ"
    case harpsichord = "Harpsichord"
    
    // Guitars
    case acousticGuitar = "Acoustic Guitar"
    case electricGuitar = "Electric Guitar"
    case bassGuitar = "Bass Guitar"
    
    // Percussion
    case timpani = "Timpani"
    case snareDrum = "Snare Drum"
    case bassDrum = "Bass Drum"
    case cymbals = "Cymbals"
    case xylophone = "Xylophone"
    case marimba = "Marimba"
    case vibraphone = "Vibraphone"
    case glockenspiel = "Glockenspiel"

    static var strings: [Instrument] { [.violin, .viola, .cello, .doubleBass, .harp] }
    static var woodwinds: [Instrument] { [.flute, .piccolo, .oboe, .englishHorn, .clarinet, .bassClarinet, .bassoon, .contrabassoon, .saxophone] }
    static var brass: [Instrument] { [.frenchHorn, .trumpet, .trombone, .bassTrombone, .tuba] }
    static var keyboards: [Instrument] { [.piano, .organ, .harpsichord] }
    static var guitars: [Instrument] { [.acousticGuitar, .electricGuitar, .bassGuitar] }
    static var percussion: [Instrument] { [.timpani, .snareDrum, .bassDrum, .cymbals, .xylophone, .marimba, .vibraphone, .glockenspiel] }
}

// A helper struct to create sections for the Picker.
struct InstrumentSection: Identifiable {
    let id = UUID()
    let name: String
    let instruments: [Instrument]
}

// An array of sections used to populate the Picker UI.
let instrumentSections: [InstrumentSection] = [
    InstrumentSection(name: "Strings", instruments: Instrument.strings),
    InstrumentSection(name: "Woodwinds", instruments: Instrument.woodwinds),
    InstrumentSection(name: "Brass", instruments: Instrument.brass),
    InstrumentSection(name: "Keyboards", instruments: Instrument.keyboards),
    InstrumentSection(name: "Guitars", instruments: Instrument.guitars),
    InstrumentSection(name: "Percussion", instruments: Instrument.percussion)
]


public enum MediaType: String, Codable, CaseIterable, Identifiable {
    case audioRecording = "Audio"
    case youtubeVideo = "YouTube"
    case spotifyLink = "Spotify"
    case appleMusicLink = "Apple Music"
    case sheetMusic = "Sheet Music"
    case localVideo = "Local Video"

    public var id: String { rawValue }
}

public enum PieceType: String, Codable, CaseIterable {
    case song = "Song"
    case scale = "Scale"
    case warmUp = "Warm-up"
    case exercise = "Exercise"
}

public enum LessonLocation: String, Codable, CaseIterable {
    case home = "Home"
    case school = "School"
    case privateLesson = "Private Lesson"
    case clinic = "Clinic"
}

public enum PlayType: String, Codable, CaseIterable {
    case learning = "Learning"
    case practice = "Practice"
    case review = "Review"
}

enum SongSortOption: String, CaseIterable, Identifiable {
    case title = "Title"
    case playCount = "Play Count"
    case recentlyPlayed = "Recently Played"

    var id: String { rawValue }
}
