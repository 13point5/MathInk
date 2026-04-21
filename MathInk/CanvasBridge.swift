import Foundation
import PencilKit

@MainActor
final class CanvasBridge: ObservableObject {
    weak var canvasView: PKCanvasView?
    weak var toolPicker: PKToolPicker?

    func attach(canvasView: PKCanvasView, toolPicker: PKToolPicker) {
        self.canvasView = canvasView
        self.toolPicker = toolPicker
    }

    func apply(command: InkCommand) {
        guard let canvasView else { return }

        canvasView.tool = command.makePKTool()
        toolPicker?.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()
    }

    func showToolPicker() {
        guard let canvasView else { return }

        toolPicker?.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()
    }
}

