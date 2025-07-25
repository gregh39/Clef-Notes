//
//  PDFKitView.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/24/25.
//


// Clef Notes/Views/PDFKitView.swift

import SwiftUI
import PDFKit

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: data)
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // No update needed
    }
}