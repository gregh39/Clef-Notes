import SwiftUI
import Foundation
import CoreData

// A new enum for the award categories
public enum AwardCategory: String, CaseIterable {
    case consistency = "Consistency"
    case milestones = "Milestones"
    case variety = "Variety"
    case featureUsage = "Feature Usage"
}

public enum Award: String, CaseIterable, Identifiable {
    // Original Awards
    case firstSession = "First Session"
    case sevenDayStreak = "7-Day Streak"
    case thirtyDayStreak = "30-Day Streak"
    case hundredPlays = "100 Total Plays"
    case songMastery = "Song Mastery"

    // New Awards
    case perfectWeek = "Perfect Week"
    case weekendWarrior = "Weekend Warrior"
    case dedicatedHour = "Dedicated Hour"
    case marathonMusician = "Marathon Musician"
    case repertoireBuilder = "Repertoire Builder"
    case virtuosoVolume = "Virtuoso Volume"
    case wellRounded = "Well-Rounded"
    case composerCollector = "Composer Collector"
    case doodlePad = "Doodle Pad"
    case recordKeeper = "Record Keeper"

    public var id: String { self.rawValue }

    // This new property assigns each award to a category
    var category: AwardCategory {
        switch self {
        case .firstSession, .sevenDayStreak, .thirtyDayStreak, .perfectWeek, .weekendWarrior:
            return .consistency
        
        case .hundredPlays, .songMastery, .marathonMusician, .repertoireBuilder, .virtuosoVolume, .dedicatedHour:
            return .milestones

        case .wellRounded, .composerCollector:
            return .variety
            
        case .doodlePad, .recordKeeper:
            return .featureUsage
        }
    }
    
    // This new property identifies awards that can be won multiple times.
    var isRepeatable: Bool {
        switch self {
        case .sevenDayStreak, .thirtyDayStreak, .hundredPlays, .virtuosoVolume, .songMastery, .perfectWeek, .weekendWarrior:
            return true
        default:
            return false
        }
    }

    var description: String {
        switch self {
        case .firstSession: "Log your very first practice session."
        case .sevenDayStreak: "Maintain a practice streak for 7 days in a row."
        case .thirtyDayStreak: "Keep a practice streak going for a full 30 days."
        case .hundredPlays: "Accumulate 100 total plays across all songs."
        case .songMastery: "Complete the play goal for any song."
        case .perfectWeek: "Practice every day of a calendar week."
        case .weekendWarrior: "Practice on both Saturday and Sunday in the same week."
        case .dedicatedHour: "Log a single session that lasts 60 minutes or more."
        case .marathonMusician: "Accumulate 10 hours of total practice time."
        case .repertoireBuilder: "Add 10 different songs to a student's list."
        case .virtuosoVolume: "Reach a total of 500 plays across all songs."
        case .wellRounded: "Practice a Song, a Scale, and an Exercise in a single session."
        case .composerCollector: "Add songs from 5 different composers."
        case .doodlePad: "Add a sketch to one of your notes."
        case .recordKeeper: "Make your first audio recording during a session."
        }
    }

    var icon: String {
        switch self {
        case .firstSession: "sparkles"
        case .sevenDayStreak: "flame.fill"
        case .thirtyDayStreak: "crown.fill"
        case .hundredPlays: "music.mic"
        case .songMastery: "star.fill"
        case .perfectWeek: "calendar.badge.checkmark"
        case .weekendWarrior: "figure.walk"
        case .dedicatedHour: "hourglass"
        case .marathonMusician: "medal.fill"
        case .repertoireBuilder: "music.note.house.fill"
        case .virtuosoVolume: "guitars.fill"
        case .wellRounded: "chart.pie.fill"
        case .composerCollector: "books.vertical.fill"
        case .doodlePad: "pencil.and.scribble"
        case .recordKeeper: "waveform.badge.mic"
        }
    }
}


public enum Instrument: String, CaseIterable, Identifiable {
    public var id: String { self.rawValue }

    // Strings
    case violin = "Violin"
    case viola = "Viola"
    case cello = "Cello"
    case doubleBass = "Bass"
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
    
    var color: Color {
        switch self {
        case .home: .blue
        case .school: .orange
        case .privateLesson: .purple
        case .clinic: .green
        }
    }
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

enum AppIcon: String, CaseIterable, Identifiable {
    case bassClef = "AppIcon"
    case trebleClef = "TrebleClefIcon"
    case altoClef = "AltoClefIcon"
    
    var id: String { self.rawValue }
    
    var iconName: String? {
        switch self {
        case .bassClef:
            return nil
        default:
            return self.rawValue
        }
    }
    
    var preview: String {
        switch self {
        case .bassClef:
            return "AppIconPreview"
        case .trebleClef:
            return "TrebleClefIconPreview"
        case .altoClef:
            return "AltoClefIconPreview"
        }
    }
}

public enum SuzukiBook: String, CaseIterable, Identifiable {
    case book1 = "Book 1"
    case book2 = "Book 2"
    case book3 = "Book 3"
    case book4 = "Book 4"
    case book5 = "Book 5"
    case book6 = "Book 6"
    case book7 = "Book 7"
    case book8 = "Book 8"
    case book9 = "Book 9"
    case book10 = "Book 10"

    public var id: String { self.rawValue }
}

enum StudentDetailSection: String, CaseIterable, Identifiable {
    case sessions = "Sessions"
    case songs = "Songs"
    case stats = "Stats"
    case awards = "Awards"
    case notes = "Notes"

    var id: String { self.rawValue }

    var systemImageName: String {
        switch self {
        case .sessions: "calendar"
        case .songs: "music.note"
        case .stats: "chart.bar"
        case .awards: "rosette"
        case .notes: "note.text"
        }
    }
}
