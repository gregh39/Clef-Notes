//
//  StatsViewModelCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 8/7/25.
//
import SwiftUI
import CoreData
import Foundation
import Combine

@MainActor
class StatsViewModelCD: ObservableObject {
    private let student: StudentCD
    private var cancellables = Set<AnyCancellable>()

    @Published var totalSessionsThisMonth: Int = 0
    @Published var totalPlaysThisMonth: Int = 0
    @Published var totalDurationThisMonth: String = "0m"
    @Published var last7Days: [Date] = []
    @Published var practicedDaysLast7: Int = 0
    @Published var weekdayCounts: [Int: Int] = [:]
    @Published var shortWeekdaySymbols: [String] = []
    @Published var mostPracticedSong: SongCD? = nil
    @Published var songNeedingPractice: SongCD? = nil
    @Published var firstPracticeDate: String = "N/A"
    @Published var totalPracticeDays: Int = 0
    // --- THIS IS THE FIX: New properties for new stats ---
    @Published var totalPracticeTime: String = "0m"
    @Published var pieceTypeDistribution: [PieceTypeStat] = []

    @Published var allMonths: [MonthKeyCD] = []
    @Published var monthPlayCounts: [MonthKeyCD: [Int: Int]] = [:]
    @Published var currentStreak = 0
    @Published var longestStreak = 0

    private var sessionDates: Set<Date> = []

    init(student: StudentCD) {
        self.student = student
        self.shortWeekdaySymbols = Calendar.current.shortWeekdaySymbols
    }

    func setup(context: NSManagedObjectContext) {
        recalculate()

        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: context)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recalculate()
            }
            .store(in: &cancellables)
    }

    private func recalculate() {
        let sessions = student.sessionsArray
        let calendar = Calendar.current
        let today = Date()

        let allPlays = sessions.flatMap { $0.playsArray }

        // --- THIS IS THE FIX: Calculation for new stats ---
        calculateTotalPracticeTime(from: sessions)
        calculatePieceTypeDistribution(from: allPlays)

        let monthSet = Set(sessions.map {
            let comps = calendar.dateComponents([.year, .month], from: $0.day ?? .now)
            return MonthKeyCD(year: comps.year ?? 2000, month: comps.month ?? 1)
        })
        self.allMonths = monthSet.sorted()
        self.monthPlayCounts = Dictionary(uniqueKeysWithValues: allMonths.map { key in
            let filtered = sessions.filter {
                let comps = calendar.dateComponents([.year, .month], from: $0.day ?? .now)
                return comps.year == key.year && comps.month == key.month
            }
            let counts = filtered.reduce(into: [Int: Int]()) { dict, session in
                let day = calendar.component(.day, from: session.day ?? .now)
                let total = session.playsArray.reduce(0) { $0 + Int($1.count) }
                dict[day, default: 0] += total
            }
            return (key, counts)
        })

        let monthlySessions = sessions.filter { calendar.isDate($0.day ?? .distantPast, equalTo: today, toGranularity: .month) }
        self.totalSessionsThisMonth = monthlySessions.count
        self.totalPlaysThisMonth = monthlySessions.reduce(0) { $0 + $1.playsArray.reduce(0) { $0 + Int($1.count) } }
        
        let totalMinutes = monthlySessions.reduce(0) { $0 + $1.durationMinutes }
        let hours = Int(totalMinutes) / 60
        let minutes = Int(totalMinutes) % 60
        if hours > 0 {
            self.totalDurationThisMonth = "\(hours)h \(minutes)m"
        } else {
            self.totalDurationThisMonth = "\(minutes)m"
        }

        self.last7Days = Array((0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed())
        let sessionDaySet = Set(sessions.map { calendar.startOfDay(for: $0.day ?? .distantPast) })
        self.practicedDaysLast7 = last7Days.filter { date in
            sessionDaySet.contains { calendar.isDate($0, inSameDayAs: date) }
        }.count
        self.sessionDates = sessionDaySet

        self.weekdayCounts = monthlySessions.reduce(into: [Int: Int]()) { counts, session in
            let weekday = calendar.component(.weekday, from: session.day ?? .now)
            counts[weekday, default: 0] += 1
        }

        let songPlayData = allPlays.reduce(into: [SongCD: (count: Int, goal: Int)]()) { result, play in
            guard let song = play.song else { return }
            let goal = max(Int(song.goalPlays), 1)

            var entry = result[song, default: (count: 0, goal: goal)]
            entry.count += Int(play.count)
            result[song] = entry
        }
        self.mostPracticedSong = songPlayData.max(by: { $0.value.count < $1.value.count })?.key
        self.songNeedingPractice = songPlayData.min(by: {
            let progressA = Double($0.value.count) / Double($0.value.goal)
            let progressB = Double($1.value.count) / Double($1.value.goal)
            return progressA < progressB
        })?.key

        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.day ?? .distantPast) })
        self.totalPracticeDays = uniqueDays.count
        if let firstDay = uniqueDays.min() {
            self.firstPracticeDate = firstDay.formatted(date: .abbreviated, time: .omitted)
        } else {
            self.firstPracticeDate = "N/A"
        }

        let sortedDates = sessionDaySet.sorted(by: >)
        (currentStreak, longestStreak) = calculateStreaks(from: sortedDates)
    }

    // --- THIS IS THE FIX: New calculation functions ---
    private func calculateTotalPracticeTime(from sessions: [PracticeSessionCD]) {
        let totalMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }
        let hours = Int(totalMinutes) / 60
        let minutes = Int(totalMinutes) % 60
        if hours > 0 {
            self.totalPracticeTime = "\(hours)h \(minutes)m"
        } else {
            self.totalPracticeTime = "\(minutes)m"
        }
    }

    private func calculatePieceTypeDistribution(from plays: [PlayCD]) {
        let counts = plays.reduce(into: [PieceType: Int]()) { counts, play in
            let type = play.song?.pieceType ?? .song
            counts[type, default: 0] += Int(play.count)
        }

        let colors: [PieceType: Color] = [.song: .blue, .scale: .green, .warmUp: .orange, .exercise: .purple]

        self.pieceTypeDistribution = counts.map { type, count in
            PieceTypeStat(type: type, count: count, color: colors[type] ?? .gray)
        }.sorted { $0.count > $1.count }
    }

    private func calculateStreaks(from sortedDates: [Date]) -> (current: Int, longest: Int) {
        guard !sortedDates.isEmpty else { return (0, 0) }

        let calendar = Calendar.current
        var current = 0
        var longest = 0

        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let practicedToday = sortedDates.contains(today)
        let practicedYesterday = sortedDates.contains(yesterday)

        var dateToCheck: Date

        if practicedToday {
            dateToCheck = today
        } else if practicedYesterday {
            dateToCheck = yesterday
        } else {
            dateToCheck = .distantFuture
        }

        if dateToCheck != .distantFuture {
            for date in sortedDates {
                if date == dateToCheck {
                    current += 1
                    dateToCheck = calendar.date(byAdding: .day, value: -1, to: dateToCheck)!
                } else if date < dateToCheck {
                    break
                }
            }
        }

        var streak = 0
        var lastDate: Date? = nil
        for date in sortedDates.reversed() {
            if let previousDate = lastDate {
                let diff = calendar.dateComponents([.day], from: previousDate, to: date).day ?? 0
                if diff == 1 {
                    streak += 1
                } else {
                    longest = max(longest, streak)
                    streak = 1
                }
            } else {
                streak = 1
            }
            lastDate = date
        }
        longest = max(longest, streak)

        return (current, longest)
    }

    func didPracticeOn(date: Date) -> Bool {
        sessionDates.contains { Calendar.current.isDate($0, inSameDayAs: date) }
    }
}
