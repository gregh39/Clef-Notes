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
        // --- CHANGE 1: Use a new migration key to ensure it runs again ---
        let migrationKey = "hasMigratedToCoreData_v2"
        
        let hasMigrated = UserDefaults.standard.bool(forKey: migrationKey)
        
        guard !hasMigrated else {
            return
        }
        
        logger.notice("--- Starting Data Migration (v2) from Swift Data to Core Data ---")
        
        coreDataContext.perform {
            do {
                // --- THIS IS THE FIX: Fetch all data types from Swift Data upfront ---
                logger.info("Fetching all data from SwiftData store...")
                let allOldInstructors = try swiftDataContext.fetch(FetchDescriptor<Instructor>())
                let allOldStudents = try swiftDataContext.fetch(FetchDescriptor<Student>())
                let allOldSongs = try swiftDataContext.fetch(FetchDescriptor<Song>())
                let allOldSessions = try swiftDataContext.fetch(FetchDescriptor<PracticeSession>())
                logger.info("Fetch complete. Found \(allOldStudents.count) students, \(allOldSongs.count) songs, \(allOldSessions.count) sessions.")

                // --- Build maps for efficient linking ---
                var instructorMap: [String: InstructorCD] = [:]
                for oldInstructor in allOldInstructors {
                    let newInstructor = InstructorCD(context: coreDataContext)
                    newInstructor.name = oldInstructor.name
                    instructorMap[oldInstructor.name] = newInstructor
                }
                
                var studentMap: [UUID: StudentCD] = [:]
                for oldStudent in allOldStudents {
                    let newStudent = StudentCD(context: coreDataContext)
                    newStudent.id = oldStudent.id
                    newStudent.name = oldStudent.name
                    newStudent.instrument = oldStudent.instrument
                    studentMap[oldStudent.id] = newStudent
                }
                
                var songMap: [String: SongCD] = [:] // Using title as a key for lookup
                for oldSong in allOldSongs {
                    guard let studentCD = studentMap[oldSong.studentID] else {
                        logger.warning("  [!!] Skipping song '\(oldSong.title)' because its student (ID: \(oldSong.studentID)) was not found.")
                        continue
                    }
                    let newSong = SongCD(context: coreDataContext)
                    newSong.title = oldSong.title
                    newSong.composer = oldSong.composer
                    newSong.goalPlays = Int64(oldSong.goalPlays ?? 0)
                    newSong.studentID = oldSong.studentID
                    newSong.songStatus = oldSong.songStatus
                    newSong.pieceType = oldSong.pieceType
                    newSong.student = studentCD
                    songMap[oldSong.title] = newSong
                }
                logger.info("Successfully migrated \(songMap.count) songs.")

                // --- Now, migrate sessions and link everything together ---
                for oldSession in allOldSessions {
                    guard let studentCD = studentMap[oldSession.studentID] else {
                        logger.warning("  [!!] Skipping session on '\(oldSession.day)' because its student was not found.")
                        continue
                    }
                    let newSession = PracticeSessionCD(context: coreDataContext)
                    newSession.day = oldSession.day
                    newSession.durationMinutes = Int64(oldSession.durationMinutes)
                    newSession.studentID = oldSession.studentID
                    newSession.location = oldSession.location
                    newSession.title = oldSession.title
                    newSession.student = studentCD
                    
                    if let instructorName = oldSession.instructor?.name {
                        newSession.instructor = instructorMap[instructorName]
                    }

                    // Link Plays
                    if let oldPlays = oldSession.plays, !oldPlays.isEmpty {
                        for oldPlay in oldPlays {
                            if let songTitle = oldPlay.song?.title, let newSong = songMap[songTitle] {
                                let newPlay = PlayCD(context: coreDataContext)
                                newPlay.count = Int64(oldPlay.count)
                                newPlay.playType = oldPlay.playType
                                newPlay.song = newSong
                                newPlay.session = newSession
                                logger.info("        [OK] Migrated and Linked Play for song: \(songTitle)")
                            } else {
                                logger.warning("        [!!] Could not find matching new song for a play. It may have been skipped earlier. Skipping play.")
                            }
                        }
                    }
                    
                    // Link Notes, Recordings, etc. (logic for these would go here)
                }
                
                logger.notice("--- Attempting to save migrated data... ---")
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
