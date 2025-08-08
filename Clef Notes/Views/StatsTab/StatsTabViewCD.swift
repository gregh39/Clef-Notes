// Clef Notes/Core Data Views/StatsTabViewCD.swift

import SwiftUI
import CoreData
import Combine

// --- THIS IS THE FIX: New struct for the piece type chart ---
struct PieceTypeStat: Identifiable {
    let id = UUID()
    let type: PieceType
    let count: Int
    let color: Color
}

struct MonthKey: Hashable, Comparable {
    let year: Int
    let month: Int

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        lhs.year != rhs.year ? lhs.year < rhs.year : lhs.month < rhs.month
    }

    var displayString: String {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month)) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}

struct StatsTabViewCD: View {
    @StateObject private var viewModel: StatsViewModelCD
    @Environment(\.managedObjectContext) private var viewContext
    @State private var path = NavigationPath()


    init(student: StudentCD) {
        _viewModel = StateObject(wrappedValue: StatsViewModelCD(student: student))
    }
    var body: some View {
            Form {
                Section(header: Text("Streaks")) {
                    StreakViewCD(viewModel: viewModel)
                }

                Section(header: Text("Practice Heat Map")) {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(viewModel.allMonths, id: \.self) { month in
                                    HeatMapViewCD(year: month.year, month: month.month, dayPlayCounts: viewModel.monthPlayCounts[month] ?? [:])
                                        .id(month)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .onAppear {
                            proxy.scrollTo(viewModel.allMonths.last, anchor: .trailing)
                        }
                    }
                }

                Section(header: Text("Last 7 Days: Practiced on \(viewModel.practicedDaysLast7) day\(viewModel.practicedDaysLast7 == 1 ? "" : "s")")) {
                    WeeklyPracticeViewCD(viewModel: viewModel)
                }

                Section(header: Text("Monthly Snapshot")) {
                    MonthlySummaryViewCD(viewModel: viewModel)
                }

                Section(header: Text("Sessions by Weekday")) {
                    WeekdayChartViewCD(viewModel: viewModel)
                }

                Section(header: Text("Practice Breakdown")) {
                    PieceTypeChartViewCD(viewModel: viewModel)
                }

                Section(header: Text("All-Time Stats")) {
                    AllTimeStatsViewCD(viewModel: viewModel)
                }
            }
            .onAppear {
                viewModel.setup(context: viewContext)
            }
        }
    
}


private struct StreakViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD

    var body: some View {
        HStack(spacing: 16) {
            StreakItemCD(label: "Current Streak", value: "\(viewModel.currentStreak) Days", icon: "🔥")
            StreakItemCD(label: "Longest Streak", value: "\(viewModel.longestStreak) Days", icon: "🏆")
        }
    }
}


struct MonthKeyCD: Hashable, Comparable {
    let year: Int
    let month: Int

    static func < (lhs: MonthKeyCD, rhs: MonthKeyCD) -> Bool {
        lhs.year != rhs.year ? lhs.year < rhs.year : lhs.month < rhs.month
    }
}

private struct HeatMapViewCD: View {
    let year: Int
    let month: Int
    let dayPlayCounts: [Int: Int]

    private var calendar: Calendar { Calendar(identifier: .gregorian) }

    private var daysInMonth: [Int] {
        let comps = DateComponents(year: year, month: month)
        let refDate = calendar.date(from: comps) ?? Date()
        return Array(calendar.range(of: .day, in: .month, for: refDate) ?? Range(1...31))
    }

    private var firstDayDate: Date { calendar.date(from: DateComponents(year: year, month: month)) ?? Date() }

    private var firstWeekday: Int { calendar.component(.weekday, from: firstDayDate) }

    private var paddedDays: [Int?] {
        var padded = Array(repeating: nil, count: firstWeekday - 1) + daysInMonth.map { Optional($0) }
        if padded.count % 7 != 0 {
            padded += Array(repeating: nil, count: 7 - (padded.count % 7))
        }
        return padded
    }

    private var weekRows: [[Int?]] {
        stride(from: 0, to: paddedDays.count, by: 7).map {
            Array(paddedDays[$0..<min($0 + 7, paddedDays.count)])
        }
    }

    private var weekdaySymbols: [String] { calendar.veryShortStandaloneWeekdaySymbols }

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: firstDayDate)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(currentMonthName)
                .font(.headline)
                .padding(.bottom, 2)
            HStack(spacing: 4) {
                ForEach(weekdaySymbols.indices, id: \.self) { index in
                    Text(weekdaySymbols[index]).font(.caption2).fontWeight(.bold).frame(maxWidth: .infinity)
                }
            }
            ForEach(weekRows.indices, id: \.self) { rowIdx in
                HStack(spacing: 4) {
                    ForEach(weekRows[rowIdx].indices, id: \.self) { dayIndex in
                        let dayOpt = weekRows[rowIdx][dayIndex]
                        if let day = dayOpt {
                            let count = dayPlayCounts[day, default: 0]
                            let opacity = count > 0 ? min(Double(count) / 5.0, 1.0) * 0.8 + 0.2 : 0.1
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(opacity))
                                if count > 0 {
                                    Text("\(day)").font(.caption).foregroundColor(.white).fontWeight(.bold)
                                }
                            }
                            .frame(height: 35).frame(maxWidth: .infinity)
                        } else {
                            Color.clear.frame(height: 35).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .frame(width: 320)
    }
}


private struct WeeklyPracticeViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD

    var body: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.last7Days, id: \.self) { date in
                VStack(spacing: 8) {
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ZStack {
                        Circle()
                            .fill(viewModel.didPracticeOn(date: date) ? Color.green : Color(UIColor.systemGray5))
                            .frame(width: 35, height: 35)
                        Text(date.formatted(.dateTime.day()))
                            .font(.caption)
                            .foregroundColor(viewModel.didPracticeOn(date: date) ? .white : .primary)
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct MonthlySummaryViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD

    var body: some View {
        HStack {
            StatItemCD(label: "Sessions", value: "\(viewModel.totalSessionsThisMonth)")
            Spacer()
            StatItemCD(label: "Plays", value: "\(viewModel.totalPlaysThisMonth)")
            Spacer()
            StatItemCD(label: "Total Duration", value: viewModel.totalDurationThisMonth)
        }
    }
}

private struct WeekdayChartViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD
    private var maxCount: CGFloat {
        CGFloat(viewModel.weekdayCounts.values.max() ?? 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(1...7, id: \.self) { weekday in
                VStack(spacing: 6) {
                    Text("\(viewModel.weekdayCounts[weekday, default: 0])")
                        .font(.caption2)
                        .fontWeight(.medium)
                    let count = CGFloat(viewModel.weekdayCounts[weekday, default: 0])
                    let barHeight = (count / maxCount) * 60

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.purple.gradient)
                        .frame(height: max(barHeight, 2))
                    Text(viewModel.shortWeekdaySymbols[weekday - 1])
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 5)
    }
}

// --- THIS IS THE FIX: New chart view ---
private struct PieceTypeChartViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD
    private var totalPlays: Int {
        viewModel.pieceTypeDistribution.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(viewModel.pieceTypeDistribution) { stat in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(stat.type.rawValue)
                            .font(.caption.bold())
                        Spacer()
                        Text("\(stat.count) plays")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: Double(stat.count), total: Double(totalPlays))
                        .tint(stat.color)
                }
            }
        }
    }
}




