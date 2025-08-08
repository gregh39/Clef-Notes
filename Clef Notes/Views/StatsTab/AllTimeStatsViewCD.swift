//
//  AllTimeStatsViewCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 8/7/25.
//
import SwiftUI

struct AllTimeStatsViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD

    var body: some View {
        // --- THIS IS THE FIX: Added total practice time ---
        VStack(spacing: 12) {
            StreakItemCD(label: "First Practice Date", value: viewModel.firstPracticeDate, icon: "📆")
            StreakItemCD(label: "Total Days Practiced", value: "\(viewModel.totalPracticeDays)", icon: "🗓️")
            StreakItemCD(label: "Total Practice Time", value: viewModel.totalPracticeTime, icon: "⏱️")
        }
    }
}
