//
//  SessionListView.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/1/25.
//

import SwiftUI
import Foundation
import SwiftData

struct SessionListView: View {
    @Binding var viewModel: StudentDetailViewModel
    
    var body: some View {
        // 1. Use a ScrollView for custom layout control.
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.sessions, id: \.persistentModelID) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        SessionCardView(session: session)
                    }
                    .buttonStyle(PlainButtonStyle()) // Ensures the whole card is tappable
                    .contextMenu {
                        // 2. Add a delete button to the context menu.
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
        // 3. Remove the plain list style and add a proper navigation title.
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
            // MARK: Card Header
            HStack {
                Text(session.title ?? "Practice")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(session.day.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // MARK: Card Details
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
        .background(.background.secondary) // Use a subtle background color
        .clipShape(RoundedRectangle(cornerRadius: 12)) // Use clipShape for better performance
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

#Preview {
    PreviewWrapper()
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

        // Mock student
        let student = Student(name: "Alice Example", instrument: "Cello")
        context.insert(student)

        // Mock sessions
        let session1 = PracticeSession(day: Date(), durationMinutes: 45, studentID: student.id)
        session1.title = "Lesson 1"
        session1.location = LessonLocation.privateLesson
        session1.instructor = Instructor(name: "Mr. Smith")

        let session2 = PracticeSession(day: Date().addingTimeInterval(-86400), durationMinutes: 30, studentID: student.id)
        session2.title = "Practice"
        session2.location = LessonLocation.home

        context.insert(session1)
        context.insert(session2)

        let viewModel = StudentDetailViewModel(student: student, context: context)
        return viewModel
    }
}
