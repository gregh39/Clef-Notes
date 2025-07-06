//
//  Student.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/12/25.
//
import SwiftUI
import SwiftData

@Model
final class Student: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String = ""
    var instrument: String = ""

    var songs: [Song]? = []
    var sessions: [PracticeSession]? = []

    init(name: String, instrument: String) {
        self.name = name
        self.instrument = instrument
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case instrument
        // songs intentionally excluded
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let instrument = try container.decode(String.self, forKey: .instrument)
        self.init(name: name, instrument: instrument)
        self.id = id
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(instrument, forKey: .instrument)
    }

    // MARK: - Hashable

    static func == (lhs: Student, rhs: Student) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
