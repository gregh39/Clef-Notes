import SwiftUI
import CoreData

struct StudentDetailViewCD: View {
    @ObservedObject var student: StudentCD
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioManager: AudioManager
    
    // --- CHANGE 1: Add a path to manage the navigation stack ---
    @State private var path = NavigationPath()
    
    @State private var showingAddSongSheet = false
    @State private var showingAddSessionSheet = false

    var body: some View {
        // --- CHANGE 2: Wrap the content in a NavigationStack ---
        NavigationStack(path: $path) {
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
            .navigationTitle(student.name ?? "Student")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSongSheet = true
                    } label: {
                        Label("Add Song", image: "add.song")
                    }
                    Button {
                        showingAddSessionSheet = true
                    } label: {
                        Label("Add Session", systemImage: "calendar.badge.plus")
                    }
                }
            }
            .withGlobalTools()
            // --- CHANGE 3: Add navigation destinations for different data types ---
            .navigationDestination(for: PracticeSessionCD.self) { session in
                SessionDetailViewCD(session: session, audioManager: audioManager)
            }
            .navigationDestination(for: SongCD.self) { song in
                SongDetailViewCD(song: song, audioManager: audioManager)
            }
        }
        .sheet(isPresented: $showingAddSessionSheet) {
            AddSessionSheetCD(student: student) { session in
                // --- CHANGE 4: Programmatically navigate by appending to the path ---
                path.append(session)
            }
        }
        .sheet(isPresented: $showingAddSongSheet) {
            AddSongSheetCD(student: student)
        }
    }
}

