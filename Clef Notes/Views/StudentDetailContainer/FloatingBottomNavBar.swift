//
//  FloatingBottomNavBar.swift
//  Clef Notes
//
//  Created by Greg Holland on 8/7/25.
//
import SwiftUI

struct FloatingBottomNavBar: View {
    @Binding var selectedSection: StudentDetailSection

    var body: some View {
        HStack {
            ForEach(StudentDetailSection.allCases) { section in
                Button(action: {
                    withAnimation(.spring()) {
                        selectedSection = section
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: section.systemImageName)
                            .font(.system(size: 22))
                        Text(section.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedSection == section ? .accentColor : .gray)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(
            Capsule()
                .fill(Material.bar)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
