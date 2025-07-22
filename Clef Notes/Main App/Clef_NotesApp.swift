import SwiftUI
import CoreData

@main
struct Clef_NotesApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // --- THIS IS THE FIX: Create and manage the session timer ---
    @StateObject private var sessionTimerManager: SessionTimerManager

    init() {
        let context = PersistenceController.shared.persistentContainer.viewContext
        _sessionTimerManager = StateObject(wrappedValue: SessionTimerManager(context: context))
    }
        
    var body: some Scene {
        WindowGroup {
            ContentView()
               .environment(\.managedObjectContext, PersistenceController.shared.persistentContainer.viewContext)
               .environmentObject(AudioManager())
               // --- THIS IS THE FIX: Inject the timer manager into the environment ---
               .environmentObject(sessionTimerManager)
        }
    }
}
