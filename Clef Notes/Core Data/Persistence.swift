//
//  Persistence.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//

import CoreData
import SwiftData

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
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}

class DataMigrator {
    
    static func migrate(from swiftDataContext: ModelContext, to coreDataContext: NSManagedObjectContext) {
        let hasMigrated = UserDefaults.standard.bool(forKey: "hasMigratedToCoreData_v1")
        
        guard !hasMigrated else {
            print("Data has already been migrated. Skipping.")
            return
        }
        
        print("Starting data migration from Swift Data to Core Data...")
        
        coreDataContext.perform {
            do {
                // 1. Fetch all Instructors from Swift Data
                let instructorDescriptor = FetchDescriptor<Instructor>()
                let oldInstructors = try swiftDataContext.fetch(instructorDescriptor)
                var instructorMap: [String: InstructorCD] = [:]

                for oldInstructor in oldInstructors {
                    let newInstructor = InstructorCD(context: coreDataContext)
                    newInstructor.name = oldInstructor.name
                    instructorMap[oldInstructor.name] = newInstructor
                }
                
                // 2. Fetch all Students from Swift Data
                let studentDescriptor = FetchDescriptor<Student>()
                let oldStudents = try swiftDataContext.fetch(studentDescriptor)
                
                for oldStudent in oldStudents {
                    let newStudent = StudentCD(context: coreDataContext)
                    newStudent.id = oldStudent.id
                    newStudent.name = oldStudent.name
                    newStudent.instrument = oldStudent.instrument
                    
                    // 3. Migrate associated Songs for each Student
                    if let oldSongs = oldStudent.songs {
                        for oldSong in oldSongs {
                            let newSong = SongCD(context: coreDataContext)
                            newSong.title = oldSong.title
                            newSong.composer = oldSong.composer
                            newSong.goalPlays = Int64(oldSong.goalPlays ?? 0)
                            newSong.studentID = oldSong.studentID
                            newSong.songStatus = oldSong.songStatus
                            newSong.pieceType = oldSong.pieceType
                            newSong.student = newStudent
                            
                            // 4. Migrate associated Plays for each Song
                            if let oldPlays = oldSong.plays {
                                for oldPlay in oldPlays {
                                    let newPlay = PlayCD(context: coreDataContext)
                                    newPlay.count = Int64(oldPlay.count)
                                    newPlay.playType = oldPlay.playType
                                    newPlay.song = newSong
                                    // Session will be linked later
                                }
                            }
                            
                            // ... (Migration for MediaReference, Note, AudioRecording for the song)
                        }
                    }
                    
                    // 5. Migrate associated Sessions for each Student
                    if let oldSessions = oldStudent.sessions {
                        for oldSession in oldSessions {
                            let newSession = PracticeSessionCD(context: coreDataContext)
                            newSession.day = oldSession.day
                            newSession.durationMinutes = Int64(oldSession.durationMinutes)
                            newSession.studentID = oldSession.studentID
                            newSession.location = oldSession.location
                            newSession.title = oldSession.title
                            newSession.student = newStudent
                            
                            // Link instructor
                            if let instructorName = oldSession.instructor?.name {
                                newSession.instructor = instructorMap[instructorName]
                            }
                            
                            // Link plays to this session
                            // --- THIS IS THE FIX ---
                            if let oldPlays = oldSession.plays {
                                let newSongPlays = newStudent.songsArray.flatMap({ $0.playsArray })
                                for oldPlay in oldPlays {
                                    // This matching is simplistic. A more robust way would be to use a unique ID on the Play model.
                                    if let matchingNewPlay = newSongPlays.first(where: { $0.song?.title == oldPlay.song?.title && $0.count == oldPlay.count && $0.session == nil }) {
                                        matchingNewPlay.session = newSession
                                    }
                                }
                            }
                            
                             // ... (Migration for Note, AudioRecording for the session)
                        }
                    }
                }
                
                try coreDataContext.save()
                UserDefaults.standard.set(true, forKey: "hasMigratedToCoreData_v1")
                print("Data migration completed successfully.")
                
            } catch {
                print("Data migration failed: \(error)")
                // Consider rolling back changes if migration fails
                coreDataContext.rollback()
            }
        }
    }
}
