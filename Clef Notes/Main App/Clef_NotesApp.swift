import SwiftUI
import CoreData

@main
struct Clef_NotesApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
        
    var body: some Scene {

        WindowGroup {
            ContentView()
               .environment(\.managedObjectContext, PersistenceController.shared.persistentContainer.viewContext)
               .environmentObject(AudioManager())
        }

    }
}
