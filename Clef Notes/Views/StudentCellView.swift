//
//  StudentCellView.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/26/25.
//
import SwiftUI
import Combine
import CoreData

private struct StudentCellView: View {
    @ObservedObject var student: StudentCD
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var currentStreak: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(student.sessionsArray.map { calendar.startOfDay(for: $0.day ?? .distantPast) })
        let sortedDates = uniqueDays.sorted(by: >)

        guard !sortedDates.isEmpty else { return 0 }

        var streak = 0
        var dateToMatch = calendar.startOfDay(for: .now)

        if !sortedDates.contains(dateToMatch) {
            dateToMatch = calendar.date(byAdding: .day, value: -1, to: dateToMatch)!
            if !sortedDates.contains(dateToMatch) {
                return 0
            }
        }

        for practiceDate in sortedDates {
            if practiceDate == dateToMatch {
                streak += 1
                dateToMatch = calendar.date(byAdding: .day, value: -1, to: dateToMatch)!
            } else {
                break
            }
        }
        return streak
    }

    var body: some View {
        HStack(spacing: 8) {
            if let avatarData = student.avatar, let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(student.name ?? "Unknown Student")
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    if student.isShared {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.secondary)
                    }
                }
                Text(student.instrument ?? "No Instrument")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider().padding(.vertical, 2)
                
                HStack(spacing: 16) {
                    HStack{
                        Image(systemName: "flame.fill")
                        Text("\(currentStreak) Day Streak")
                    }
                    .foregroundColor(currentStreak > 0 ? .orange : .secondary)
                    Spacer()
                    if let lastSessionDate = student.sessionsArray.first?.day {
                        HStack{
                            Image(systemName: "clock.arrow.circlepath")
                            Text(Self.dateFormatter.string(from: lastSessionDate))
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
