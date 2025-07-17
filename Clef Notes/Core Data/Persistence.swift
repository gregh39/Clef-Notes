import CoreData
import SwiftData
import os.log

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "ClefNotesCD")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}

class DataMigrator {
    
    private static let logger = Logger(subsystem: "com.yourcompany.Clef-Notes", category: "DataMigration")
    
    static func migrate(from swiftDataContext: ModelContext, to coreDataContext: NSManagedObjectContext) {
        // --- Use a new key to ensure this full migration runs ---
        let migrationKey = "hasMigratedToCoreData_v4"
        
        let hasMigrated = UserDefaults.standard.bool(forKey: migrationKey)
        
        guard !hasMigrated else {
            return
        }
        
        logger.notice("--- Starting Comprehensive Data Migration (v4) ---")
        
        coreDataContext.perform {
            do {
                // --- 1. Fetch ALL old data upfront ---
                logger.info("Fetching all data from SwiftData store...")
                let allOldInstructors = try swiftDataContext.fetch(FetchDescriptor<Instructor>())
                let allOldStudents = try swiftDataContext.fetch(FetchDescriptor<Student>())
                let allOldSongs = try swiftDataContext.fetch(FetchDescriptor<Song>())
                let allOldSessions = try swiftDataContext.fetch(FetchDescriptor<PracticeSession>())
                let allOldNotes = try swiftDataContext.fetch(FetchDescriptor<Note>())
                let allOldRecordings = try swiftDataContext.fetch(FetchDescriptor<AudioRecording>())
                let allOldMediaRefs = try swiftDataContext.fetch(FetchDescriptor<MediaReference>())
                let allOldPlays = try swiftDataContext.fetch(FetchDescriptor<Play>())
                logger.info("Fetch complete: \(allOldStudents.count) students, \(allOldSongs.count) songs, \(allOldSessions.count) sessions, \(allOldPlays.count) plays, \(allOldNotes.count) notes, \(allOldRecordings.count) recordings, \(allOldMediaRefs.count) media references.")

                // --- 2. Create new Core Data objects and map them ---
                var instructorMap: [String: InstructorCD] = [:]
                for old in allOldInstructors {
                    let new = InstructorCD(context: coreDataContext)
                    new.name = old.name
                    instructorMap[old.name] = new
                }
                
                var studentMap: [UUID: StudentCD] = [:]
                for old in allOldStudents {
                    let new = StudentCD(context: coreDataContext)
                    new.id = old.id
                    new.name = old.name
                    new.instrument = old.instrument
                    studentMap[old.id] = new
                }
                
                var songMap: [String: SongCD] = [:] // Key: "\(studentID)-\(title)"
                for old in allOldSongs {
                    guard let studentCD = studentMap[old.studentID] else { continue }
                    let new = SongCD(context: coreDataContext)
                    new.title = old.title
                    new.composer = old.composer
                    new.goalPlays = Int64(old.goalPlays ?? 0)
                    new.studentID = old.studentID
                    new.songStatus = old.songStatus
                    new.pieceType = old.pieceType
                    new.student = studentCD
                    songMap["\(old.studentID)-\(old.title)"] = new
                }
                logger.info("Successfully created \(songMap.count) new Song objects.")

                var sessionMap: [String: PracticeSessionCD] = [:] // Key: "\(studentID)-\(date)"
                for old in allOldSessions {
                    guard let studentCD = studentMap[old.studentID] else { continue }
                    let new = PracticeSessionCD(context: coreDataContext)
                    new.day = old.day
                    new.durationMinutes = Int64(old.durationMinutes)
                    new.studentID = old.studentID
                    new.location = old.location
                    new.title = old.title
                    new.student = studentCD
                    if let instructorName = old.instructor?.name {
                        new.instructor = instructorMap[instructorName]
                    }
                    sessionMap["\(old.studentID)-\(old.day)"] = new
                }
                logger.info("Successfully created \(sessionMap.count) new Session objects.")

                // --- 3. Now, iterate and link all remaining objects ---
                
                logger.info("Linking \(allOldPlays.count) Plays...")
                for old in allOldPlays {
                    // --- THIS IS THE FIX: The guard now only requires a song ---
                    guard let songTitle = old.song?.title, let studentID = old.song?.studentID, let newSong = songMap["\(studentID)-\(songTitle)"] else {
                        logger.warning("[!!] Skipping a Play because its parent Song could not be found.")
                        continue
                    }
                    
                    let new = PlayCD(context: coreDataContext)
                    new.count = Int64(old.count)
                    new.playType = old.playType
                    new.song = newSong
                    
                    // --- THIS IS THE FIX: Optionally link the session if it exists ---
                    if let sessionDay = old.session?.day, let newSession = sessionMap["\(studentID)-\(sessionDay)"] {
                        new.session = newSession
                        logger.info("        [OK] Migrated and Linked Play for song '\(songTitle)' to session on \(sessionDay.formatted(date: .short, time: .omitted))")
                    } else {
                        // This play has no session, which is valid.
                        logger.info("        [OK] Migrated Play for song '\(songTitle)' (No Session)")
                    }
                }
                
                logger.info("Linking \(allOldMediaRefs.count) Media References...")
                for old in allOldMediaRefs {
                    guard let songTitle = old.song?.title, let studentID = old.song?.studentID, let newSong = songMap["\(studentID)-\(songTitle)"] else { continue }
                    let new = MediaReferenceCD(context: coreDataContext)
                    new.type = old.type
                    new.url = old.url
                    new.title = old.title
                    new.notes = old.notes
                    new.duration = old.duration ?? 0.0
                    new.data = old.data
                    new.song = newSong
                }
                
                logger.info("Linking \(allOldNotes.count) Notes...")
                for old in allOldNotes {
                    let new = NoteCD(context: coreDataContext)
                    new.text = old.text
                    new.drawing = old.drawing
                    if let sessionDay = old.session?.day, let studentID = old.session?.studentID, let newSession = sessionMap["\(studentID)-\(sessionDay)"] {
                        new.session = newSession
                    }
                    if let taggedSongs = old.songs, !taggedSongs.isEmpty {
                        let newTaggedSongs = taggedSongs.compactMap { songMap["\($0.studentID)-\($0.title)"] }
                        new.songs = NSSet(array: newTaggedSongs)
                    }
                }
                
                logger.info("Linking \(allOldRecordings.count) Audio Recordings...")
                for old in allOldRecordings {
                    let new = AudioRecordingCD(context: coreDataContext)
                    new.id = old.id
                    new.title = old.title
                    new.data = old.data
                    new.dateRecorded = old.dateRecorded
                    new.duration = old.duration ?? 0.0
                    if let sessionDay = old.session?.day, let studentID = old.session?.studentID, let newSession = sessionMap["\(studentID)-\(sessionDay)"] {
                        new.session = newSession
                    }
                    if let taggedSongs = old.songs, !taggedSongs.isEmpty {
                        let newTaggedSongs = taggedSongs.compactMap { songMap["\($0.studentID)-\($0.title)"] }
                        new.songs = NSSet(array: newTaggedSongs)
                    }
                }

                logger.notice("--- Attempting to save all migrated data... ---")
                try coreDataContext.save()
                
                UserDefaults.standard.set(true, forKey: migrationKey)
                logger.notice("--- Data migration completed successfully. Flag set. ---")
                
            } catch {
                logger.critical("--- Data migration FAILED: \(error.localizedDescription) ---")
                logger.critical("--- Rolling back changes. No data was saved. ---")
                coreDataContext.rollback()
            }
        }
    }
}
