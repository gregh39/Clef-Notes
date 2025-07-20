import SwiftUI
import CoreData
import CloudKit

struct StudentDetailViewCD: View {
    @ObservedObject var student: StudentCD
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioManager: AudioManager
    
    // --- CHANGE 1: Add a path to manage the navigation stack ---
    @State private var path = NavigationPath()
    
    @State private var showingAddSongSheet = false
    @State private var showingAddSessionSheet = false
    
    // --- THIS IS THE FIX ---
    @State private var isSharePresented = false
    @State private var cloudSharingController: UICloudSharingController?
    // --- END OF FIX ---
    
    // Added per instructions
    @State private var showingMigrationSheet = false
    @State private var migrationResult: StudentCD.MigrationResult? = nil
    
    func populateStudentReferences() {
        // Songs
        if let songs = student.songs as? Set<SongCD> {
            for song in songs {
                if song.student !== student {
                    song.student = student
                }
                // Ensure inverse
                if !(student.songs?.contains(song) ?? false) {
                    student.addToSongs(song)
                }
            }
        }
        // Sessions
        if let sessions = student.sessions as? Set<PracticeSessionCD> {
            for session in sessions {
                if session.student !== student {
                    session.student = student
                }
                if !(student.sessions?.contains(session) ?? false) {
                    student.addToSessions(session)
                }
            }
        }
        // Plays
        if let plays = student.plays as? Set<PlayCD> {
            for play in plays {
                if play.student !== student {
                    play.student = student
                }
                if !(student.plays?.contains(play) ?? false) {
                    student.mutableSetValue(forKey: "plays").add(play)
                }
            }
        }
        // Notes
        if let notes = student.notes as? Set<NoteCD> {
            for note in notes {
                if note.student !== student {
                    note.student = student
                }
                if !(student.notes?.contains(note) ?? false) {
                    student.mutableSetValue(forKey: "notes").add(note)
                }
            }
        }
        // Media References
        if let mediaRefs = student.mediaReferences as? Set<MediaReferenceCD> {
            for mediaRef in mediaRefs {
                if mediaRef.student !== student {
                    mediaRef.student = student
                }
                if !(student.mediaReferences?.contains(mediaRef) ?? false) {
                    student.mutableSetValue(forKey: "mediaReferences").add(mediaRef)
                }
            }
        }
        // Audio Recordings
        if let recordings = student.audioRecordings as? Set<AudioRecordingCD> {
            for recording in recordings {
                if recording.student !== student {
                    recording.student = student
                }
                if !(student.audioRecordings?.contains(recording) ?? false) {
                    student.mutableSetValue(forKey: "audioRecordings").add(recording)
                }
            }
        }
        // Instructors (if you have instructor->student as well)
        if let instructors = student.instructors as? Set<InstructorCD> {
            for instructor in instructors {
                // If InstructorCD has a single student property:
                if let iStudent = instructor.value(forKey: "student") as? StudentCD, iStudent !== student {
                    instructor.setValue(student, forKey: "student")
                }
                // If InstructorCD has students as a set, add student
                if let students = instructor.value(forKey: "student") as? NSSet, !students.contains(student) {
                    instructor.mutableSetValue(forKey: "student").add(student)
                }
                if !(student.instructors?.contains(instructor) ?? false) {
                    student.mutableSetValue(forKey: "instructors").add(instructor)
                }
            }
        }
        // Save context
        do {
            try viewContext.save()
        } catch {
            print("Failed to save context after populating student references: \(error)")
        }
    }

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
                    // --- THIS IS THE FIX ---
                    Button {
                        isSharePresented = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    // --- END OF FIX ---
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
        // --- THIS IS THE FIX ---
        .sheet(isPresented: $isSharePresented) {
            CloudSharingView(student: student)
        }
        // --- END OF FIX ---
        // Added per instructions
        .sheet(isPresented: $showingMigrationSheet) {
            if let result = migrationResult {
                MigrationResultSheet(result: result)
            }
        }
    }
}

struct MigrationResultSheet: View {
    let result: StudentCD.MigrationResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Updated Objects")) {
                    HStack { Text("Plays"); Spacer(); Text("\(result.playCount)") }
                    HStack { Text("Notes"); Spacer(); Text("\(result.noteCount)") }
                    HStack { Text("Media References"); Spacer(); Text("\(result.mediaReferenceCount)") }
                    HStack { Text("Audio Recordings"); Spacer(); Text("\(result.audioRecordingCount)") }
                    HStack { Text("Instructors"); Spacer(); Text("\(result.instructorCount)") }
                }
            }
            .navigationTitle("Migration Results")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
