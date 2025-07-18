import SwiftUI
import CoreData
import CloudKit

@main
struct Clef_NotesApp: App {
    // This line connects your AppDelegate to the SwiftUI app lifecycle.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
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
