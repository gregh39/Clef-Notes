//
//  StatsTabView.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/15/25.
//
import Foundation
import SwiftUI
import SwiftData

struct StatsTabView: View {
    let sessions: [PracticeSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
            Text("Practice Heat Map (This Month)")
                .font(.headline)
                .padding(.bottom, 5)

            let calendar = Calendar.current
            let today = Date()
            let range = calendar.range(of: .day, in: .month, for: today) ?? 1..<31
            let days = Array(range)
            let monthPlays: [Int: Int] = sessions
                .filter { calendar.isDate($0.day, equalTo: today, toGranularity: .month) }
                .reduce(into: [Int: Int]()) { counts, session in
                    let day = calendar.component(.day, from: session.day)
                    let total = session.plays.reduce(0) { $0 + $1.count }
                    counts[day, default: 0] += total
                }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { day in
                    let count = monthPlays[day, default: 0]
                    ZStack {
                        Rectangle()
                            .foregroundColor(Color.blue.opacity(Double(min(count, 5)) / 5.0 + 0.1))
                            .cornerRadius(4)
                        Text("\(day)")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(height: 30)
                }
            }
            .padding()
            
            Divider()
                .padding(.vertical)

            let lastWeekDates = (1...7).compactMap {
                Calendar.current.date(byAdding: .day, value: -$0, to: Date())
            }.reversed()
            let sessionDates = Set(sessions.map(\.day))
            let practicedDays = lastWeekDates.filter { day in
                sessionDates.contains { Calendar.current.isDate($0, inSameDayAs: day) }
            }

            Text("Last 7 Days: Practiced on \(practicedDays.count) day\(practicedDays.count == 1 ? "" : "s")")
                .font(.headline)

            HStack {
                ForEach(lastWeekDates, id: \.self) { date in
                    let didPractice = sessionDates.contains { Calendar.current.isDate($0, inSameDayAs: date) }
                    ZStack {
                        Circle()
                            .fill(didPractice ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 30, height: 30)
                        Text(DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .none).prefix(1))
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .overlay(
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.caption2)
                            .foregroundColor(.white)
                    )
                }
            }
            
            Divider()
                .padding(.vertical)

            // Total sessions and plays this month
            let totalSessionsThisMonth = sessions.filter {
                calendar.isDate($0.day, equalTo: today, toGranularity: .month)
            }
            let totalPlaysThisMonth = totalSessionsThisMonth.reduce(0) { $0 + $1.plays.reduce(0) { $0 + $1.count } }
            let avgPlaysPerSession = totalSessionsThisMonth.isEmpty ? 0 : totalPlaysThisMonth / totalSessionsThisMonth.count

            Text("📅 Total Sessions This Month: \(totalSessionsThisMonth.count)")
            Text("🎯 Total Plays This Month: \(totalPlaysThisMonth)")
            Text("⚖️ Avg Plays per Session: \(avgPlaysPerSession)")
                .padding(.bottom)

            Divider()
                .padding(.vertical)

            // Weekday distribution
            let weekdayCounts = totalSessionsThisMonth.reduce(into: [Int: Int]()) { counts, session in
                let weekday = calendar.component(.weekday, from: session.day)
                counts[weekday, default: 0] += 1
            }

            Text("📈 Sessions by Weekday")
                .font(.headline)
            HStack {
                ForEach(1...7, id: \.self) { weekday in
                    VStack {
                        Text("\(weekdayCounts[weekday, default: 0])")
                            .font(.caption)
                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: 10, height: CGFloat(weekdayCounts[weekday, default: 0]) * 10)
                        Text(calendar.shortWeekdaySymbols[weekday - 1])
                            .font(.caption2)
                    }
                }
            }

            Divider()
                .padding(.vertical)

            // Song practice stats
            let songs = sessions.flatMap { $0.plays.map { ($0.song, $0.count) } }
                .reduce(into: [Song: Int]()) { result, entry in
                    if let song = entry.0 {
                        result[song, default: 0] += entry.1
                    }
                }

            if let mostPlayed = songs.max(by: { $0.value < $1.value })?.key {
                Text("🎵 Most Practiced Song: \(mostPlayed.title)")
            }

            if let leastComplete = songs.min(by: {
                guard let leftGoal = $0.key.goalPlays, let rightGoal = $1.key.goalPlays else { return false }
                let leftProgress = Double($0.value) / Double(leftGoal)
                let rightProgress = Double($1.value) / Double(rightGoal)
                return leftProgress < rightProgress
            })?.key {
                Text("⏳ Song Needing Most Practice: \(leastComplete.title)")
            }

            Divider()
                .padding(.vertical)

            // First session and total practice days
            let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.day) })
            if let firstDay = uniqueDays.min() {
                Text("📆 First Practice Date: \(firstDay.formatted(date: .abbreviated, time: .omitted))")
            }
            Text("🗓️ Total Days Practiced: \(uniqueDays.count)")
        }
        .padding()
    }
    }
}
