//
//  Untitled.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/15/25.
//

import Foundation
import SwiftData

@Model
final class Instructor {
    var name: String = ""
    
    @Relationship(deleteRule: .nullify, inverse: \PracticeSession.instructor)
    var sessions: [PracticeSession]? = []

    init(name: String) {
        self.name = name
    }
}
