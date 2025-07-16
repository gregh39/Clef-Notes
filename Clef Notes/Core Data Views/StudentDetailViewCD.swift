import SwiftUI
import CoreData

struct StudentDetailViewCD: View {
    @ObservedObject var student: StudentCD
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioManager: AudioManager
    
    @State private var showingAddSongSheet = false
    @State private var showingAddSessionSheet = false
    
    // State for navigating to a new session's detail view
    @State private var newSession: PracticeSessionCD?
    @State private var navigateToNewSession = false

    var body: some View {
        VStack {
            // Invisible NavigationLink for programmatic navigation
            NavigationLink(destination: Text("Session Detail (Refactor Needed)"), isActive: $navigateToNewSession) {
                EmptyView()
            }
            
            TabView {
                SessionListViewCD(student: student) {
                    showingAddSessionSheet = true
                }
                .tabItem {
                    Label("Sessions", systemImage: "calendar")
                }
                
                StudentSongsTabViewCD(student: student) {
                    showingAddSongSheet = true
                }
                .tabItem { Label("Songs", systemImage: "music.note.list") }

                StatsTabViewCD(student: student)
                    .tabItem { Label("Stats", systemImage: "chart.bar") }
            }
        }
        .navigationTitle(student.name ?? "Student")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingAddSongSheet = true
                } label: {
                    Label {
                        Text("Add Song")
                    } icon: {
                        Image("add.song")
                    }
                }
                Button {
                    showingAddSessionSheet = true
                } label: {
                    Label("Add Session", systemImage: "calendar.badge.plus")
                }
            }
        }
        .withGlobalTools()
        .sheet(isPresented: $showingAddSessionSheet) {
            AddSessionSheetCD(student: student) { session in
                // When a session is added, trigger navigation
                newSession = session
                navigateToNewSession = true
            }
        }
        .sheet(isPresented: $showingAddSongSheet) {
            AddSongSheetCD(student: student)
        }
    }
}
