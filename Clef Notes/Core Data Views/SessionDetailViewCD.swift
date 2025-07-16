//
//  SessionDetailViewCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//


import SwiftUI
import CoreData

struct SessionDetailViewCD: View {
    @ObservedObject var session: PracticeSessionCD
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        // The content for this view will be refactored next
        Text("Detail view for session on \((session.day ?? .now).formatted(date: .abbreviated, time: .omitted))")
            .navigationTitle(session.title ?? "Session")
    }
}
