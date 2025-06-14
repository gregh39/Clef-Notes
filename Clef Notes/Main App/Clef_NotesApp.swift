//
//  Clef_NotesApp.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/10/25.
//

import SwiftUI
import SwiftData

@main
struct Clef_NotesApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Student.self,
            Song.self,
            PracticeSession.self,
            Play.self,
            Note.self,
            MediaReference.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
