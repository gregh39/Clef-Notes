// SongFirebaseRepository.swift
// Handles basic Firestore operations for Song model

import Foundation
import FirebaseFirestore
//import FirebaseFirestoreSwift

struct SongDTO: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var composer: String?
    var goalPlays: Int?
    var studentID: UUID? // Use UUID for parity with Swift model
    var songStatus: String? // You may encode PlayType as String raw value
    var pieceType: String? // You may encode PieceType as String raw value
    // Relationships as arrays of IDs (if needed)
    var playIDs: [String]? // IDs for related Play objects
    var mediaIDs: [String]? // IDs for related MediaReference objects
    var noteIDs: [String]? // IDs for related Note objects
    var recordingIDs: [String]? // IDs for related AudioRecording objects

    // Computed properties (these only count IDs here, you must calculate true values in your view model using related data)
    var totalPlayCount: Int {
        return playIDs?.count ?? 0
    }
    var totalGoalPlayCount: Int {
        // This is a placeholder: you need to actually fetch Play objects to filter by playType == .practice
        return playIDs?.count ?? 0
    }
    var lastPlayedDate: Date? {
        // Placeholder: requires fetching Play objects and their sessions' dates
        return nil
    }
}

class SongFirebaseRepository {
    private let collection = Firestore.firestore().collection("songs")

    func addSong(_ song: SongDTO, completion: ((Error?) -> Void)? = nil) {
        do {
            _ = try collection.addDocument(from: song) { error in
                completion?(error)
            }
        } catch {
            completion?(error)
        }
    }

    func updateSong(_ song: SongDTO, completion: ((Error?) -> Void)? = nil) {
        guard let id = song.id else {
            completion?(NSError(domain: "Missing song ID", code: -1))
            return
        }
        do {
            try collection.document(id).setData(from: song, merge: true, completion: completion)
        } catch {
            completion?(error)
        }
    }

    func fetchAllSongs(completion: @escaping ([SongDTO]?, Error?) -> Void) {
        collection.getDocuments { snapshot, error in
            if let error = error {
                completion(nil, error)
            } else {
                let songs = snapshot?.documents.compactMap { try? $0.data(as: SongDTO.self) }
                completion(songs, nil)
            }
        }
    }
}
