//
//  SongFilterSheet.swift
//  Clef Notes
//
//  Created by Greg Holland on 8/7/25.
//
import SwiftUI
import CoreData

struct SongFilterSheet: View {
    let availablePieceTypes: [PieceType]
    @Binding var selectedPieceType: PieceType?
    let isSuzuki: Bool
    @Binding var selectedSuzukiBook: SuzukiBook?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Piece Type") {
                    Picker("Filter by Type", selection: $selectedPieceType) {
                        Text("All Types").tag(nil as PieceType?)
                        ForEach(availablePieceTypes, id: \.self) { type in
                            Text(type.rawValue).tag(Optional(type))
                        }
                    }
                }
                
                if isSuzuki {
                    Section("Suzuki Book") {
                        Picker("Filter by Book", selection: $selectedSuzukiBook) {
                            Text("All Books").tag(nil as SuzukiBook?)
                            ForEach(SuzukiBook.allCases) { book in
                                Text(book.rawValue).tag(Optional(book))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        selectedPieceType = nil
                        selectedSuzukiBook = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
