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

    @discardableResult
    func setZoomScale(_ scale: CGFloat, animated: Bool = true) -> CGFloat? {
        guard let canvasView else { return nil }

        let targetScale = clampedZoomScale(scale, for: canvasView)
        let visibleCenter = CGPoint(
            x: canvasView.contentOffset.x + canvasView.bounds.width / 2,
            y: canvasView.contentOffset.y + canvasView.bounds.height / 2
        )

        zoom(canvasView, toScale: targetScale, centeredOn: visibleCenter, animated: animated)
        canvasView.becomeFirstResponder()
        return targetScale
    }

    @discardableResult
    func zoomToFitContent(animated: Bool = true) -> CGFloat? {
        guard let canvasView else { return nil }

        let drawingBounds = canvasView.drawing.bounds
        guard !drawingBounds.isEmpty else {
            return setZoomScale(1, animated: animated)
        }

        let paddedBounds = drawingBounds.insetBy(dx: -160, dy: -160)
        let horizontalScale = canvasView.bounds.width / max(paddedBounds.width, 1)
        let verticalScale = canvasView.bounds.height / max(paddedBounds.height, 1)
        let targetScale = clampedZoomScale(min(horizontalScale, verticalScale), for: canvasView)

        zoom(
            canvasView,
            toScale: targetScale,
            centeredOn: CGPoint(x: paddedBounds.midX, y: paddedBounds.midY),
            animated: animated
        )
        canvasView.becomeFirstResponder()
        return targetScale
    }

    private func clampedZoomScale(_ scale: CGFloat, for canvasView: PKCanvasView) -> CGFloat {
        min(max(scale, canvasView.minimumZoomScale), canvasView.maximumZoomScale)
    }

    private func zoom(_ canvasView: PKCanvasView, toScale scale: CGFloat, centeredOn center: CGPoint, animated: Bool) {
        let visibleSize = CGSize(
            width: max(canvasView.bounds.width / scale, 1),
            height: max(canvasView.bounds.height / scale, 1)
        )
        let proposedRect = CGRect(
            x: center.x - visibleSize.width / 2,
            y: center.y - visibleSize.height / 2,
            width: visibleSize.width,
            height: visibleSize.height
        )

        canvasView.zoom(to: proposedRect.clamped(to: canvasView.contentSize), animated: animated)
    }
}

private extension CGRect {
    func clamped(to contentSize: CGSize) -> CGRect {
        guard contentSize.width > 0, contentSize.height > 0 else { return self }

        let originX = min(max(origin.x, 0), max(contentSize.width - width, 0))
        let originY = min(max(origin.y, 0), max(contentSize.height - height, 0))
        return CGRect(origin: CGPoint(x: originX, y: originY), size: size)
    }
}
