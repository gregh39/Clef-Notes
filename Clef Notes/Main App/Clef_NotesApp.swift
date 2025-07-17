import SwiftUI
import CoreData

@main
struct Clef_NotesApp: App {
    @StateObject private var audioManager = AudioManager()
    
    let persistenceController = PersistenceController.shared
    
    @AppStorage("selectedAccentColor") private var selectedColor: AccentColor = .blue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(audioManager)
        }
    }
}
