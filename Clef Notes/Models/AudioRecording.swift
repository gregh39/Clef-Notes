//
//  AudioRecording.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/16/25.
//
import SwiftUI
import Foundation
import SwiftData

@Model
final class AudioRecording {
    var title: String?
    var fileURL: URL
    var dateRecorded: Date
    var duration: TimeInterval?

    @Relationship var session: PracticeSession?

    init(fileURL: URL, dateRecorded: Date = .now, title: String? = nil, duration: TimeInterval? = nil) {
        self.fileURL = fileURL
        self.dateRecorded = dateRecorded
        self.title = title
        self.duration = duration
    }
}
