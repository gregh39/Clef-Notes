//
//  SongStatsViewCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 8/7/25.
//
import SwiftUI

struct SongStatsViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        VStack(spacing: 12) {
            if let song = viewModel.mostPracticedSong {
                NavigationLink(value: song) {
                    StatItemCD(label: "Most Practiced", value: song.title ?? "N/A")
                }
                .buttonStyle(.plain)
            } else {
                StatItemCD(label: "Most Practiced", value: "N/A")
            }

            if let song = viewModel.songNeedingPractice {
                NavigationLink(value: song) {
                    StatItemCD(label: "Needs Practice", value: song.title ?? "N/A")
                }
                .buttonStyle(.plain)
            } else {
                StatItemCD(label: "Needs Practice", value: "N/A")
            }
        }
    }
}
