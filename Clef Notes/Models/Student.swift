//
//  Student.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/12/25.
//
import SwiftUI
import SwiftData

@Model
final class Student: Identifiable, Hashable {
    @Attribute(.unique) var id: UUID = UUID() // Explicit ID
    var name: String
    var instrument: String

    init(name: String, instrument: String) {
        self.name = name
        self.instrument = instrument
    }

    static func == (lhs: Student, rhs: Student) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
