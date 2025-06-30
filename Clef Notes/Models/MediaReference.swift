//
//  MediaReference.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/12/25.
//
import SwiftData
import SwiftUI

@Model
final class MediaReference {
    var type: MediaType = MediaType.audioRecording
    var url: URL?
    var title: String?
    var notes: String?
    
    @Relationship var song: Song?

    init(type: MediaType, url: URL, title: String? = nil, notes: String? = nil) {
        self.type = type
        self.url = url
        self.title = title
        self.notes = notes
    }
}

