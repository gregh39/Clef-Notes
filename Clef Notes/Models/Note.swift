//
//  Note.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/12/25.
//
import SwiftData
import Swift
import Foundation

@Model
final class Note {
    var text: String = ""
    @Relationship var session: PracticeSession?
    @Relationship var songs: [Song]? = [] 
    
    @Attribute(.externalStorage)
    var drawing: Data?


    init(text: String, drawing: Data? = nil) {
        self.text = text
        self.drawing = drawing

    }
}
