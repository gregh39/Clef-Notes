import Foundation
import CoreData
import AVFoundation

/// Helper utility to migrate existing audio files and set their duration
class AudioDurationMigrationHelper {

    /// Migrates all MediaReferenceCD and AudioRecordingCD objects that have audio data but no duration
    static func migrateAudioDurations(context: NSManagedObjectContext) {
        context.perform {
            var updatedCount = 0

            // Migrate MediaReferenceCD objects
            let mediaFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "MediaReferenceCD")
            mediaFetchRequest.predicate = NSPredicate(format: "duration == 0 AND data != nil AND typeRaw == %@", MediaType.audioRecording.rawValue)

            if let mediaReferences = try? context.fetch(mediaFetchRequest) as? [MediaReferenceCD] {
                for media in mediaReferences {
                    if let data = media.data {
                        media.duration = extractDuration(from: data)
                        updatedCount += 1
                        print("Updated MediaReference: \(media.title ?? "Unknown") - Duration: \(media.duration)s")
                    }
                }
            }

            // Migrate AudioRecordingCD objects
            let audioFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AudioRecordingCD")
            audioFetchRequest.predicate = NSPredicate(format: "duration == 0 AND data != nil")

            if let audioRecordings = try? context.fetch(audioFetchRequest) as? [AudioRecordingCD] {
                for audio in audioRecordings {
                    if let data = audio.data {
                        audio.duration = extractDuration(from: data)
                        updatedCount += 1
                        print("Updated AudioRecording: \(audio.title ?? "Unknown") - Duration: \(audio.duration)s")
                    }
                }
            }

            // Save if any changes were made
            if updatedCount > 0 {
                do {
                    try context.save()
                    print("✅ Audio duration migration complete: \(updatedCount) items updated")
                } catch {
                    print("❌ Failed to save audio duration migration: \(error)")
                }
            } else {
                print("ℹ️ No audio files needed duration migration")
            }
        }
    }

    private static func extractDuration(from data: Data) -> Double {
        do {
            let player = try AVAudioPlayer(data: data)
            return player.duration
        } catch {
            print("Failed to extract audio duration: \(error)")
            return 0
        }
    }
}
