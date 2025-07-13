import SwiftUI
import Foundation
import SwiftData

struct SessionListView: View {
    @Binding var viewModel: StudentDetailViewModel
    @EnvironmentObject var audioManager: AudioManager // <-- ADDED

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.sessions, id: \.persistentModelID) { session in
                    // Pass the audioManager to the SessionDetailView
                    NavigationLink(destination: SessionDetailView(session: session, audioManager: audioManager)) { // <-- FIXED
                        SessionCardView(session: session)
                    }
                    .buttonStyle(PlainButtonStyle()) // Ensures the whole card is tappable
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteSession(session)
                        } label: {
                            Label("Delete Session", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .navigationTitle("Sessions")
    }
    
    /// Deletes a specific session and saves the context.
    private func deleteSession(_ session: PracticeSession) {
        viewModel.context.delete(session)
        try? viewModel.context.save()
        viewModel.practiceVM.reload() // Assuming this reloads the data
    }
}

struct SessionCardView: View {
    let session: PracticeSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.title ?? "Practice")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(session.day.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                if let location = session.location {
                    Label(location.rawValue, systemImage: "mappin.and.ellipse")
                }
                Spacer()
                if let instructor = session.instructor {
                    Label(instructor.name, systemImage: "person.fill")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

#Preview {
    // The preview now correctly includes the AudioManager in its environment.
    PreviewWrapper()
        .environmentObject(AudioManager())
}

struct PreviewWrapper: View {
    @State var viewModel = StudentDetailViewModel.mock

    var body: some View {
        NavigationStack {
            SessionListView(viewModel: $viewModel)
        }
    }
}

extension StudentDetailViewModel {
    static var mock: StudentDetailViewModel {
        let container = try! ModelContainer(for: Student.self, PracticeSession.self, Instructor.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let student = Student(name: "Alice Example", instrument: "Cello")
        context.insert(student)

        let session1 = PracticeSession(day: Date(), durationMinutes: 45, studentID: student.id)
        session1.title = "Lesson 1"
        session1.location = LessonLocation.privateLesson
        session1.instructor = Instructor(name: "Mr. Smith")

        let session2 = PracticeSession(day: Date().addingTimeInterval(-86400), durationMinutes: 30, studentID: student.id)
        session2.title = "Practice"
        session2.location = LessonLocation.home

        context.insert(session1)
        context.insert(session2)

        return StudentDetailViewModel(student: student, context: context)
    }
}
