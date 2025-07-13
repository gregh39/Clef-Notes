import SwiftUI
import SwiftData

@main
struct Clef_NotesApp: App {
    // Create a single, shared instance of the AudioManager.
    @StateObject private var audioManager = AudioManager()
    
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
                .tint(selectedColor.color)
                // Inject the AudioManager into the environment.
                // Now, any view in the app can access it using @EnvironmentObject.
                .environmentObject(audioManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
