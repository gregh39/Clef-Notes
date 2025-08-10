//
//  TabContext.swift
//  Clef Notes
//
//  Created by Greg Holland on 8/8/25.
//


import SwiftUI

enum TabContext { case sessions, songs, stats, awards, notes }

struct CommonToolbar: ToolbarContent {
    let context: TabContext
    let onMenu: () -> Void
    let onAddSong: () -> Void
    let onAddSession: () -> Void
    let onAddNote: () -> Void
    let canCreateSong: () -> Bool
    let canCreateSession: () -> Bool
    let showPaywall: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            Button(action: onMenu) {
                Label("Menu", systemImage: "line.3.horizontal")
            }
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            switch context {
            case .sessions, .songs:
                Button {
                    canCreateSong() ? onAddSong() : showPaywall()
                } label: {
                    Label("Add Song", image: "add.song")
                }
                Button {
                    canCreateSession() ? onAddSession() : showPaywall()
                } label: {
                    Label("Add Session", systemImage: "calendar.badge.plus")
                }

            case .notes:
                Button(action: onAddNote) {
                    Label("Add Note", systemImage: "note.text.badge.plus")
                }

            case .stats, .awards:
                EmptyView()
            }
        }
    }
}