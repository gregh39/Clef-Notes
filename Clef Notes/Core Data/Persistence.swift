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
    
    // --- CHANGE 1: Create a dedicated logger for clarity ---
    private static let logger = Logger(subsystem: "com.yourcompany.Clef-Notes", category: "DataMigration")
    
    static func migrate(from swiftDataContext: ModelContext, to coreDataContext: NSManagedObjectContext) {
        let hasMigrated = UserDefaults.standard.bool(forKey: "hasMigratedToCoreData_v1")
        
        guard !hasMigrated else {
            return // No need to log if we're not migrating.
        }
        
        logger.notice("--- Starting Data Migration from Swift Data to Core Data ---")
        
        coreDataContext.perform {
            do {
                // --- Instructors ---
                let instructorDescriptor = FetchDescriptor<Instructor>()
                let oldInstructors = try swiftDataContext.fetch(instructorDescriptor)
                var instructorMap: [String: InstructorCD] = [:]
                logger.info("Found \(oldInstructors.count) instructors to migrate.")
                for oldInstructor in oldInstructors {
                    let newInstructor = InstructorCD(context: coreDataContext)
                    newInstructor.name = oldInstructor.name
                    instructorMap[oldInstructor.name] = newInstructor
                    logger.info("  [OK] Migrated Instructor: \(oldInstructor.name)")
                }

                // --- Students ---
                let studentDescriptor = FetchDescriptor<Student>()
                let oldStudents = try swiftDataContext.fetch(studentDescriptor)
                logger.info("Found \(oldStudents.count) students to migrate.")
                
                for oldStudent in oldStudents {
                    let newStudent = StudentCD(context: coreDataContext)
                    newStudent.id = oldStudent.id
                    newStudent.name = oldStudent.name
                    newStudent.instrument = oldStudent.instrument
                    logger.info("  [OK] Migrating Student: \(oldStudent.name) (\(oldStudent.instrument))")

                    // --- Songs ---
                    if let oldSongs = oldStudent.songs, !oldSongs.isEmpty {
                        logger.info("    Found \(oldSongs.count) songs for \(oldStudent.name).")
                        for oldSong in oldSongs {
                            let newSong = SongCD(context: coreDataContext)
                            newSong.title = oldSong.title
                            newSong.composer = oldSong.composer
                            newSong.goalPlays = Int64(oldSong.goalPlays ?? 0)
                            newSong.studentID = oldSong.studentID
                            newSong.songStatus = oldSong.songStatus
                            newSong.pieceType = oldSong.pieceType
                            newSong.student = newStudent
                            logger.info("      [OK] Migrated Song: \(newSong.title ?? "Untitled")")

                            // --- Media References for Song ---
                            if let oldMedia = oldSong.media, !oldMedia.isEmpty {
                                for oldMediaRef in oldMedia {
                                    let newMediaRef = MediaReferenceCD(context: coreDataContext)
                                    newMediaRef.type = oldMediaRef.type
                                    newMediaRef.url = oldMediaRef.url
                                    newMediaRef.title = oldMediaRef.title
                                    newMediaRef.notes = oldMediaRef.notes
                                    newMediaRef.duration = oldMediaRef.duration ?? 0.0
                                    newMediaRef.data = oldMediaRef.data
                                    newMediaRef.song = newSong
                                    logger.info("        [OK] Migrated Media: \(newMediaRef.title ?? "Untitled Media")")
                                }
                            }
                        }
                    }

                    // --- Sessions ---
                    if let oldSessions = oldStudent.sessions, !oldSessions.isEmpty {
                        logger.info("    Found \(oldSessions.count) sessions for \(oldStudent.name).")
                        for oldSession in oldSessions {
                            let newSession = PracticeSessionCD(context: coreDataContext)
                            newSession.day = oldSession.day
                            newSession.durationMinutes = Int64(oldSession.durationMinutes)
                            newSession.studentID = oldSession.studentID
                            newSession.location = oldSession.location
                            newSession.title = oldSession.title
                            newSession.student = newStudent
                            logger.info("      [OK] Migrated Session: \(newSession.title ?? "Untitled") on \(oldSession.day.formatted(date: .abbreviated, time: .omitted))")

                            if let instructorName = oldSession.instructor?.name {
                                newSession.instructor = instructorMap[instructorName]
                                logger.info("        [OK] Linked Instructor: \(instructorName)")
                            }

                            // --- Plays ---
                            if let oldPlays = oldSession.plays, !oldPlays.isEmpty {
                                for oldPlay in oldPlays {
                                    if let songTitle = oldPlay.song?.title,
                                       let newSong = newStudent.songsArray.first(where: { $0.title == songTitle }) {
                                        let newPlay = PlayCD(context: coreDataContext)
                                        newPlay.count = Int64(oldPlay.count)
                                        newPlay.playType = oldPlay.playType
                                        newPlay.song = newSong
                                        newPlay.session = newSession
                                        logger.info("        [OK] Migrated and Linked Play for song: \(songTitle)")
                                    } else {
                                        logger.warning("        [!!] Could not find matching new song for a play. Skipping.")
                                    }
                                }
                            }
                            
                            // --- Notes ---
                            if let oldNotes = oldSession.notes, !oldNotes.isEmpty {
                                for oldNote in oldNotes {
                                    let newNote = NoteCD(context: coreDataContext)
                                    newNote.text = oldNote.text
                                    newNote.drawing = oldNote.drawing
                                    newNote.session = newSession
                                    
                                    if let taggedSongs = oldNote.songs, !taggedSongs.isEmpty {
                                        let taggedSongTitles = taggedSongs.map { $0.title }
                                        let newTaggedSongs = newStudent.songsArray.filter { taggedSongTitles.contains($0.title ?? "") }
                                        newNote.songs = NSSet(array: newTaggedSongs)
                                        logger.info("        [OK] Migrated Note and tagged \(newTaggedSongs.count) songs.")
                                    } else {
                                        logger.info("        [OK] Migrated Note with no tags.")
                                    }
                                }
                            }
                            
                            // --- Audio Recordings ---
                            if let oldRecordings = oldSession.recordings, !oldRecordings.isEmpty {
                                for oldRecording in oldRecordings {
                                    let newRecording = AudioRecordingCD(context: coreDataContext)
                                    newRecording.id = oldRecording.id
                                    newRecording.title = oldRecording.title
                                    newRecording.data = oldRecording.data
                                    newRecording.dateRecorded = oldRecording.dateRecorded
                                    newRecording.duration = oldRecording.duration ?? 0.0
                                    newRecording.session = newSession
                                    
                                    if let taggedSongs = oldRecording.songs, !taggedSongs.isEmpty {
                                        let taggedSongTitles = taggedSongs.map { $0.title }
                                        let newTaggedSongs = newStudent.songsArray.filter { taggedSongTitles.contains($0.title ?? "") }
                                        newRecording.songs = NSSet(array: newTaggedSongs)
                                        logger.info("        [OK] Migrated Recording and tagged \(newTaggedSongs.count) songs.")
                                    } else {
                                        logger.info("        [OK] Migrated Recording with no tags.")
                                    }
                                }
                            }
                        }
                    }
                }
                
                logger.notice("--- Attempting to save migrated data... ---")
                try coreDataContext.save()
                
                UserDefaults.standard.set(true, forKey: "hasMigratedToCoreData_v1")
                logger.notice("--- Data migration completed successfully. Flag set. ---")
                
            } catch {
                logger.critical("--- Data migration FAILED: \(error.localizedDescription) ---")
                logger.critical("--- Rolling back changes. No data was saved. ---")
                coreDataContext.rollback()
            }
        }
    }
}

