//
//  StudentCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//


import Foundation
import CoreData

@objc(StudentCD)
public class StudentCD: NSManagedObject {

}

extension StudentCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StudentCD> {
        return NSFetchRequest<StudentCD>(entityName: "StudentCD")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var instrument: String?
    @NSManaged public var name: String?
    @NSManaged public var sessions: NSSet?
    @NSManaged public var songs: NSSet?
    @NSManaged public var plays: NSSet?
    @NSManaged public var notes: NSSet?
    @NSManaged public var mediaReferences: NSSet?
    @NSManaged public var instructors: NSSet?
    @NSManaged public var audioRecordings: NSSet?
    
    public var songsArray: [SongCD] {
        let set = songs as? Set<SongCD> ?? []
        // Provide a default sort order for the songs array
        return set.sorted { (lhs: SongCD, rhs: SongCD) in
            lhs.title ?? "" < rhs.title ?? ""
        }
    }
    
    public var sessionsArray: [PracticeSessionCD] {
        let set = sessions as? Set<PracticeSessionCD> ?? []
        // Provide a default sort order for the sessions array
        return set.sorted { (lhs: PracticeSessionCD, rhs: PracticeSessionCD) in
            lhs.day ?? .distantPast > rhs.day ?? .distantPast
        }
    }

}

// MARK: Generated accessors for sessions
extension StudentCD {

    @objc(addSessionsObject:)
    @NSManaged public func addToSessions(_ value: PracticeSessionCD)

    @objc(removeSessionsObject:)
    @NSManaged public func removeFromSessions(_ value: PracticeSessionCD)

    @objc(addSessions:)
    @NSManaged public func addToSessions(_ values: NSSet)

    @objc(removeSessions:)
    @NSManaged public func removeFromSessions(_ values: NSSet)

}

// MARK: Generated accessors for songs
extension StudentCD {

    @objc(addSongsObject:)
    @NSManaged public func addToSongs(_ value: SongCD)

    @objc(removeSongsObject:)
    @NSManaged public func removeFromSongs(_ value: SongCD)

    @objc(addSongs:)
    @NSManaged public func addToSongs(_ values: NSSet)

    @objc(removeSongs:)
    @NSManaged public func removeFromSongs(_ values: NSSet)

}

extension StudentCD : Identifiable {

}

// MARK: - Migration Utility
extension StudentCD {
    struct MigrationResult {
        var playCount: Int
        var noteCount: Int
        var mediaReferenceCount: Int
        var audioRecordingCount: Int
        var instructorCount: Int
    }
    
    /// Assigns the only Student to every related object in the database that supports a student relationship, for migration purposes.
    /// This skips PracticeSessionCD and SongCD (which are already set).
    static func assignStudentToAllObjects(context: NSManagedObjectContext) -> MigrationResult {
        let studentReq: NSFetchRequest<StudentCD> = StudentCD.fetchRequest()
        studentReq.fetchLimit = 1
        guard let student = try? context.fetch(studentReq).first else {
            print("No Student found")
            return MigrationResult(playCount: 0, noteCount: 0, mediaReferenceCount: 0, audioRecordingCount: 0, instructorCount: 0)
        }

        var playCount = 0
        var noteCount = 0
        var mediaReferenceCount = 0
        var audioRecordingCount = 0
        var instructorCount = 0

        func assign<T: NSManagedObject>(_ resultType: T.Type, setBlock: @escaping (T) -> Bool) {
            let req = NSFetchRequest<T>(entityName: String(describing: resultType))
            if let objects = try? context.fetch(req) {
                for obj in objects {
                    if setBlock(obj) {
                        // counted by closure
                    }
                }
            }
        }

        assign(PlayCD.self) { play in
            var updated = false
            if play.student !== student {
                play.student = student
                updated = true
            }
            if !(student.plays?.contains(play) ?? false) {
                student.mutableSetValue(forKey: "plays").add(play)
                updated = true
            }
            if updated { playCount += 1 }
            return updated
        }
        assign(NoteCD.self) { note in
            var updated = false
            if note.student !== student {
                note.student = student
                updated = true
            }
            if !(student.notes?.contains(note) ?? false) {
                student.mutableSetValue(forKey: "notes").add(note)
                updated = true
            }
            if updated { noteCount += 1 }
            return updated
        }
        assign(MediaReferenceCD.self) { mediaRef in
            var updated = false
            if mediaRef.student !== student {
                mediaRef.student = student
                updated = true
            }
            if !(student.mediaReferences?.contains(mediaRef) ?? false) {
                student.mutableSetValue(forKey: "mediaReferences").add(mediaRef)
                updated = true
            }
            if updated { mediaReferenceCount += 1 }
            return updated
        }
        assign(AudioRecordingCD.self) { recording in
            var updated = false
            if recording.student !== student {
                recording.student = student
                updated = true
            }
            if !(student.audioRecordings?.contains(recording) ?? false) {
                student.mutableSetValue(forKey: "audioRecordings").add(recording)
                updated = true
            }
            if updated { audioRecordingCount += 1 }
            return updated
        }
        assign(InstructorCD.self) { instructor in
            var updated = false
            if let students = instructor.value(forKey: "student") as? NSSet, !students.contains(student) {
                instructor.mutableSetValue(forKey: "student").add(student)
                updated = true
            }
            if !(student.instructors?.contains(instructor) ?? false) {
                student.mutableSetValue(forKey: "instructors").add(instructor)
                updated = true
            }
            if updated { instructorCount += 1 }
            return updated
        }
        do {
            try context.save()
            print("Migration: All objects assigned to the single student.")
        } catch {
            print("Migration failed: \(error)")
        }
        return MigrationResult(playCount: playCount, noteCount: noteCount, mediaReferenceCount: mediaReferenceCount, audioRecordingCount: audioRecordingCount, instructorCount: instructorCount)
    }
}
