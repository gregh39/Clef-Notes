//
//  GlobalToolbarModifier.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/27/25.
//


import SwiftUI

struct GlobalToolbarModifier: ViewModifier {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @Binding var selectedTab: Int
    @Binding var showingAddSongSheet: Bool
    @Binding var showingAddSessionSheet: Bool
    @Binding var showingPaywall: Bool
    @Binding var triggerAddNote: Bool
    @Binding var showingSideMenu: Bool

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSideMenu = true
                    }) {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if selectedTab <= 1 {
                        Button {
                            if subscriptionManager.isAllowedToCreateSong() {
                                showingAddSongSheet = true
                            } else {
                                showingPaywall = true
                            }
                        } label: {
                            Label("Add Song", image: "add.song")
                        }
                        Button {
                            if subscriptionManager.isAllowedToCreateSession() {
                                showingAddSessionSheet = true
                            } else {
                                showingPaywall = true
                            }
                        } label: {
                            Label("Add Session", systemImage: "calendar.badge.plus")
                        }
                    } else if selectedTab == 3 {
                        Button(action: { triggerAddNote = true }) {
                            Label("Add Note", systemImage: "plus")
                        }
                    }
                    
                }
            }
    }
}

extension View {
    func withGlobalToolbar(
        selectedTab: Binding<Int>,
        showingAddSongSheet: Binding<Bool>,
        showingAddSessionSheet: Binding<Bool>,
        showingPaywall: Binding<Bool>,
        triggerAddNote: Binding<Bool>,
        showingSideMenu: Binding<Bool>
    ) -> some View {
        self.modifier(GlobalToolbarModifier(
            selectedTab: selectedTab,
            showingAddSongSheet: showingAddSongSheet,
            showingAddSessionSheet: showingAddSessionSheet,
            showingPaywall: showingPaywall,
            triggerAddNote: triggerAddNote,
            showingSideMenu: showingSideMenu
        ))
    }
}
