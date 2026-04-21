import Foundation
import PencilKit

@MainActor
final class CanvasBridge: ObservableObject {
    @Published private(set) var selectedCommand = InkCommand(tool: .pen, color: .blue)

    weak var canvasView: PKCanvasView?

    func attach(canvasView: PKCanvasView) {
        self.canvasView = canvasView
        canvasView.tool = selectedCommand.makePKTool()
    }

    func apply(command: InkCommand) {
        selectedCommand = command
        guard let canvasView else { return }

        canvasView.tool = command.makePKTool()
        canvasView.becomeFirstResponder()
    }

    func selectTool(_ tool: InkCommand.ToolKind) {
        let color = tool == .eraser ? nil : selectedCommand.color ?? .blue
        apply(command: InkCommand(tool: tool, color: color))
    }

    func selectColor(_ color: InkCommand.NamedColor) {
        let tool = selectedCommand.tool == .eraser ? InkCommand.ToolKind.pen : selectedCommand.tool
        apply(command: InkCommand(tool: tool, color: color))
    }
}
