import SwiftUI
import SwiftData
import CoreData

@main
struct Clef_NotesApp: App {
    @StateObject private var audioManager = AudioManager()
    
    // --- CHANGE 1: Initialize the Core Data stack ---
    let persistenceController = PersistenceController.shared
    
    // --- CHANGE 2: Keep the Swift Data container for migration ---
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Student.self,
            Song.self,
            PracticeSession.self,
            Play.self,
            Note.self,
            MediaReference.self,
            AudioRecording.self,
            Instructor.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @AppStorage("selectedAccentColor") private var selectedColor: AccentColor = .blue

    var body: some Scene {
        WindowGroup {
            ContentView()
                // --- CHANGE 3: Inject the Core Data context into the environment ---
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(audioManager)
                // --- CHANGE 4: Keep the Swift Data container available for the migration ---
                .modelContainer(sharedModelContainer)
        }
    }
}
