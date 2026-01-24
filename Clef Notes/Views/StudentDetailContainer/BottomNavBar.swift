//
//  BottomNavBar.swift
//  Clef Notes
//
//  Created by Greg Holland on 8/7/25.
//
import SwiftUI

struct BottomNavBar: View {
    @Binding var selectedSection: StudentDetailSection
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
            HStack {
                ForEach(StudentDetailSection.allCases) { section in
                    Button(action: {
                        withAnimation {
                            selectedSection = section
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: section.systemImageName)
                                .font(.system(size: 22))
                            Text(section.rawValue)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(selectedSection == section ? .accentColor : .gray)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.top, 5)
            .padding(.bottom, 35)
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
        }
    
}
