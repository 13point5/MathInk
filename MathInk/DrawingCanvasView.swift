import PencilKit
import SwiftUI

struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data
    @ObservedObject var canvasBridge: CanvasBridge
    let onDrawingChange: (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.backgroundColor = .systemBackground
        canvasView.drawingPolicy = .anyInput
        canvasView.alwaysBounceVertical = true
        canvasView.alwaysBounceHorizontal = true
        canvasView.tool = PKInkingTool(.pen, color: .systemBlue, width: 6)

        if let drawing = try? PKDrawing(data: drawingData) {
            canvasView.drawing = drawing
        }

        let toolPicker = PKToolPicker()
        context.coordinator.toolPicker = toolPicker
        toolPicker.addObserver(canvasView)
        toolPicker.setVisible(true, forFirstResponder: canvasView)

        canvasBridge.attach(canvasView: canvasView, toolPicker: toolPicker)

        DispatchQueue.main.async {
            canvasView.becomeFirstResponder()
        }

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvasBridge.attach(
            canvasView: uiView,
            toolPicker: context.coordinator.toolPicker ?? PKToolPicker()
        )

        let currentData = uiView.drawing.dataRepresentation()
        guard currentData != drawingData else { return }

        if drawingData.isEmpty {
            uiView.drawing = PKDrawing()
        } else if let drawing = try? PKDrawing(data: drawingData) {
            uiView.drawing = drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvasView
        var toolPicker: PKToolPicker?

        init(parent: DrawingCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.onDrawingChange(canvasView.drawing.dataRepresentation())
        }
    }
}

