//
//  CloudSyncStatusView.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/26/25.
//


//
//  CloudSyncStatusView.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/26/25.
//

import SwiftUI

struct CloudSyncStatusView: View {
    @State private var lastSyncDate: Date? = nil
    @State private var isSyncing: Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("iCloud Sync")) {
                HStack {
                    Text("Last Sync")
                    Spacer()
                    if let date = lastSyncDate {
                        Text(date, style: .relative)
                    } else {
                        Text("Never")
                    }
                }
                
                Button(action: {
                    sync()
                }) {
                    HStack {
                        Spacer()
                        if isSyncing {
                            ProgressView()
                        } else {
                            Text("Sync Now")
                        }
                        Spacer()
                    }
                }
                .disabled(isSyncing)
            }
        }
        .onAppear(perform: fetchLastSyncDate)
        .navigationTitle("Cloud Sync Status")
    }
    
    private func fetchLastSyncDate() {
        // In a real app, you would fetch this from UserDefaults or another persistent store.
        // For this example, we'll just simulate it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.lastSyncDate = Date().addingTimeInterval(-120)
        }
    }
    
    private func sync() {
        isSyncing = true
        // Simulate a network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.lastSyncDate = Date()
            self.isSyncing = false
        }
    }
}
