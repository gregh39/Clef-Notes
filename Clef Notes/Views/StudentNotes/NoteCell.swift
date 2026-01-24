//
//  NoteCell.swift
//  Clef Notes
//
//  Created by Greg Holland on 8/7/25.
//
import SwiftUI
import PencilKit

struct NoteCell: View {

    @ObservedObject var note: NoteCD

    var onTap: () -> Void

    var body: some View {

        Button(action: onTap) {

            HStack(alignment: .center, spacing: 15) {

                VStack {

                    if let drawingData = note.drawing, !drawingData.isEmpty,

                       let drawing = try? PKDrawing(data: drawingData) {

                        Image(uiImage: drawing.image(from: drawing.bounds, scale: UIScreen.main.scale))

                            .resizable()

                            .scaledToFit()

                            .frame(width: 40, height: 40)

                            .background(Color(UIColor.systemBackground))

                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            .overlay(

                                RoundedRectangle(cornerRadius: 6)

                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)

                            )

                    } else {

                        Image(systemName: "doc.text.fill")

                            .font(.system(size: 24))

                            .frame(width: 40, height: 40)

                            .background(Color.accentColor.opacity(0.1))

                            .foregroundColor(.accentColor)

                            .cornerRadius(6)

                    }

                }

  

                VStack(alignment: .leading, spacing: 5) {

                    if !note.songsArray.isEmpty {

                        Text(note.songsArray.map { $0.title ?? "" }.joined(separator: ", "))

                            .font(.caption.weight(.bold))

                            .foregroundColor(.secondary)

                            .lineLimit(1)

                    }

                    if let text = note.text, !text.isEmpty {

                        Text(text)

                            .font(.body)

                            .foregroundColor(.primary)

                            .lineLimit(2)

                    } else if note.drawing == nil || note.drawing!.isEmpty {

                        Text("Empty Note")

                            .font(.body)

                            .foregroundColor(.secondary)

                    } else {

                        Text("Sketch")

                            .font(.body)

                            .foregroundColor(.secondary)

                    }

                }

                Spacer()

            }

            .padding(12)

            .background(Color(UIColor.secondarySystemGroupedBackground))

            .cornerRadius(12)

        }

        .buttonStyle(.plain)

        .listRowSeparator(.hidden)

        .listRowInsets(EdgeInsets())

    }

}
