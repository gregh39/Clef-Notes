import SwiftUI
import PencilKit

struct DrawingView: UIViewRepresentable {
    @Binding var drawingData: Data
    
    private static var toolPicker = PKToolPicker()
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = .anyInput
        
        // --- THIS IS THE FIX ---
        // 1. Enable scrolling and set a larger canvas size.
        canvasView.isScrollEnabled = true
        canvasView.minimumZoomScale = 1.0
        canvasView.maximumZoomScale = 2.0 // Allow users to zoom in
        
        // Set a content size much larger than the frame to allow scrolling.
        // This creates a large "paper" for the user to draw on.
        canvasView.contentSize = CGSize(width: 2000, height: 3000)
        
        if let drawing = try? PKDrawing(data: drawingData) {
            canvasView.drawing = drawing
        }
        
        DrawingView.toolPicker.setVisible(true, forFirstResponder: canvasView)
        DrawingView.toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // No change needed here
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingView

        init(_ parent: DrawingView) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawingData = canvasView.drawing.dataRepresentation()
        }
    }
}
