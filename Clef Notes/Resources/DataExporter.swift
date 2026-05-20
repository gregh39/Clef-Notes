import Foundation
import CoreData

class DataExporter {

    // MARK: - JSON full-database export

    /// Exports the entire database to a JSON file and returns its temporary URL.
    /// Binary audio/video data is omitted (too large); images, avatars, and drawings
    /// are included as base64 strings.
    func exportAllDataToJSON(context: NSManagedObjectContext) -> URL? {
        var root: [String: Any] = [:]
        root["exportDate"] = ISO8601DateFormatter().string(from: Date())
        root["version"] = 2

        context.performAndWait {
            root["students"]    = fetchStudents(context: context)
            root["collections"] = fetchCollections(context: context)
            root["usageTracker"] = fetchUsageTracker(context: context)
        }

        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]),
              let path = NSURL(fileURLWithPath: NSTemporaryDirectory())
                  .appendingPathComponent("ClefNotes_Backup_\(dateStamp()).json")
        else { return nil }

        do {
            try data.write(to: path)
            return path
        } catch {
            print("DataExporter: failed to write JSON: \(error)")
            return nil
        }
    }

    // MARK: - Per-entity serialisers

    private func fetchStudents(context: NSManagedObjectContext) -> [[String: Any]] {
        let request = NSFetchRequest<StudentCD>(entityName: "StudentCD")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let students = (try? context.fetch(request)) ?? []
        return students.map { serialise($0) }
    }

    private func fetchCollections(context: NSManagedObjectContext) -> [[String: Any]] {
        let request = NSFetchRequest<CollectionCD>(entityName: "CollectionCD")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let collections = (try? context.fetch(request)) ?? []
        return collections.map { col in
            var d: [String: Any] = [:]
            d["objectID"]  = col.objectID.uriRepresentation().absoluteString
            d["name"]      = col.name ?? ""
            d["songIDs"]   = (col.songs as? Set<SongCD>)?.map {
                $0.objectID.uriRepresentation().absoluteString
            } ?? []
            return d
        }
    }

    private func fetchUsageTracker(context: NSManagedObjectContext) -> [String: Any] {
        let request = NSFetchRequest<UsageTrackerCD>(entityName: "UsageTrackerCD")
        let trackers = (try? context.fetch(request)) ?? []
        guard let t = trackers.first else { return [:] }
        return [
            "totalStudentsCreated": t.totalStudentsCreated,
            "totalSongsCreated":    t.totalSongsCreated,
            "totalSessionsCreated": t.totalSessionsCreated,
            "totalMetronomeOpens":  t.totalMetronomeOpens,
            "totalTunerOpens":      t.totalTunerOpens
        ]
    }

    private func serialise(_ student: StudentCD) -> [String: Any] {
        var d: [String: Any] = [:]
        d["objectID"]         = student.objectID.uriRepresentation().absoluteString
        d["id"]               = student.id?.uuidString ?? ""
        d["name"]             = student.name
        d["instrument"]       = student.instrument
        d["suzukiStudent"]    = student.suzukiStudent
        d["suzukiBookRaw"]    = student.suzukiBookRaw ?? ""
        d["sessionCreations"] = student.sessionCreations
        d["songCreations"]    = student.songCreations
        d["avatar"]           = student.avatar.map { $0.base64EncodedString() } ?? NSNull()

        d["instructors"]   = student.instructorsArray.map { serialise($0) }
        d["earnedAwards"]  = student.earnedAwardsArray.map { serialise($0) }
        d["songs"]         = student.songsArray.map { serialise($0) }
        d["sessions"]      = student.sessionsArray.map { serialise($0) }

        // Recordings not nested under sessions to avoid duplication
        d["audioRecordings"] = student.audioRecordingsArray.map { serialise($0) }

        return d
    }

    private func serialise(_ instructor: InstructorCD) -> [String: Any] {
        [
            "objectID": instructor.objectID.uriRepresentation().absoluteString,
            "name": instructor.name ?? ""
        ]
    }

    private func serialise(_ award: EarnedAwardCD) -> [String: Any] {
        [
            "objectID":      award.objectID.uriRepresentation().absoluteString,
            "awardRawValue": award.awardRawValue ?? "",
            "count":         award.count,
            "dateWon":       award.dateWon.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull()
        ]
    }

    private func serialise(_ song: SongCD) -> [String: Any] {
        var d: [String: Any] = [:]
        d["objectID"]       = song.objectID.uriRepresentation().absoluteString
        d["title"]          = song.title
        d["composer"]       = song.composer ?? ""
        d["pieceTypeRaw"]   = song.pieceTypeRaw ?? ""
        d["songStatusRaw"]  = song.songStatusRaw ?? ""
        d["suzukiBookRaw"]  = song.suzukiBookRaw ?? ""
        d["goalPlays"]      = song.goalPlays
        d["archived"]       = song.archived
        d["studentID"]      = song.studentID?.uuidString ?? ""
        d["collectionID"]   = song.collection?.objectID.uriRepresentation().absoluteString ?? NSNull()
        d["image"]          = song.image.map { $0.base64EncodedString() } ?? NSNull()
        d["plays"]          = song.playsArray.map { serialise($0) }
        d["media"]          = song.mediaArray.map { serialise($0) }
        return d
    }

    private func serialise(_ play: PlayCD) -> [String: Any] {
        [
            "objectID":    play.objectID.uriRepresentation().absoluteString,
            "count":       play.count,
            "playTypeRaw": play.playTypeRaw ?? "",
            "sessionID":   play.session?.objectID.uriRepresentation().absoluteString ?? NSNull(),
            "songID":      play.song?.objectID.uriRepresentation().absoluteString ?? NSNull(),
            "studentID":   play.student?.objectID.uriRepresentation().absoluteString ?? NSNull()
        ]
    }

    private func serialise(_ media: MediaReferenceCD) -> [String: Any] {
        [
            "objectID": media.objectID.uriRepresentation().absoluteString,
            "title":    media.title ?? "",
            "typeRaw":  media.typeRaw,
            "url":      media.url?.absoluteString ?? "",
            "notes":    media.notes ?? "",
            "duration": media.duration
            // media.data omitted — large binary video/image
        ]
    }

    private func serialise(_ session: PracticeSessionCD) -> [String: Any] {
        var d: [String: Any] = [:]
        d["objectID"]        = session.objectID.uriRepresentation().absoluteString
        d["title"]           = session.title ?? ""
        d["day"]             = session.day.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull()
        d["durationMinutes"] = session.durationMinutes
        d["locationRaw"]     = session.locationRaw ?? ""
        d["studentID"]       = session.studentID?.uuidString ?? ""
        d["instructorID"]    = session.instructor?.objectID.uriRepresentation().absoluteString ?? NSNull()
        d["plays"]           = session.playsArray.map { serialise($0) }
        d["notes"]           = session.notesArray.map { serialise($0) }
        d["recordingIDs"]    = session.recordingsArray.map {
            $0.objectID.uriRepresentation().absoluteString
        }
        return d
    }

    private func serialise(_ note: NoteCD) -> [String: Any] {
        [
            "objectID":  note.objectID.uriRepresentation().absoluteString,
            "title":     note.title ?? "",
            "text":      note.text ?? "",
            "date":      note.date.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull(),
            "drawing":   note.drawing.map { $0.base64EncodedString() } ?? NSNull(),
            "sessionID": note.session?.objectID.uriRepresentation().absoluteString ?? NSNull(),
            "songIDs":   (note.songs as? Set<SongCD>)?.map {
                $0.objectID.uriRepresentation().absoluteString
            } ?? []
        ]
    }

    private func serialise(_ recording: AudioRecordingCD) -> [String: Any] {
        [
            "objectID":     recording.objectID.uriRepresentation().absoluteString,
            "id":           recording.id?.uuidString ?? "",
            "title":        recording.title ?? "",
            "dateRecorded": recording.dateRecorded.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull(),
            "duration":     recording.duration,
            "sessionID":    recording.session?.objectID.uriRepresentation().absoluteString ?? NSNull(),
            "songIDs":      (recording.songs as? Set<SongCD>)?.map {
                $0.objectID.uriRepresentation().absoluteString
            } ?? []
            // recording.data omitted — stored externally by CoreData, too large for JSON
        ]
    }

    // MARK: - Legacy CSV (single student)

    func exportStudentToCSV(student: StudentCD) -> URL? {
        let fileName = "\(student.name ?? "Student")_Export.csv"
        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)

        var csvText = "Session Date,Session Title,Duration (min),Song,Plays\n"

        for session in student.sessionsArray {
            let date = session.day?.formatted(.dateTime.year().month().day()) ?? "N/A"
            let title = session.title ?? "Practice"
            let duration = session.durationMinutes

            if session.playsArray.isEmpty {
                csvText.append("\(date),\(title),\(duration),,\n")
            } else {
                for play in session.playsArray {
                    let songTitle = play.song?.title ?? "N/A"
                    let plays = play.count
                    csvText.append("\(date),\(title),\(duration),\(songTitle),\(plays)\n")
                }
            }
        }

        do {
            try csvText.write(to: path!, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("Failed to create file: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    private func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmm"
        return f.string(from: Date())
    }
}

// MARK: - Convenience array accessors used by DataExporter
// (entities that don't already expose these)

private extension StudentCD {
    var instructorsArray: [InstructorCD] {
        (instructors as? Set<InstructorCD>)?.sorted { ($0.name ?? "") < ($1.name ?? "") } ?? []
    }
}
