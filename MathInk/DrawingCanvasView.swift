import PencilKit
import SwiftUI

private final class EdgeToEdgeCanvasView: PKCanvasView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        forceEdgeToEdgeLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        forceEdgeToEdgeLayout()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        forceEdgeToEdgeLayout()
    }

    func forceEdgeToEdgeLayout() {
        contentInset = .zero
        scrollIndicatorInsets = .zero
        contentInsetAdjustmentBehavior = .never
        automaticallyAdjustsScrollIndicatorInsets = false
        insetsLayoutMarginsFromSafeArea = false
        preservesSuperviewLayoutMargins = false
        layoutMargins = .zero
        directionalLayoutMargins = .zero

        let minimumContentSize = CGSize(
            width: max(bounds.width, 1),
            height: max(bounds.height, 1)
        )

        if contentSize.width < minimumContentSize.width || contentSize.height < minimumContentSize.height {
            contentSize = CGSize(
                width: max(contentSize.width, minimumContentSize.width),
                height: max(contentSize.height, minimumContentSize.height)
            )
        }

        let maximumOffset = CGPoint(
            x: max(contentSize.width - bounds.width, 0),
            y: max(contentSize.height - bounds.height, 0)
        )
        let clampedOffset = CGPoint(
            x: min(max(contentOffset.x, 0), maximumOffset.x),
            y: min(max(contentOffset.y, 0), maximumOffset.y)
        )

        if contentOffset != clampedOffset {
            setContentOffset(clampedOffset, animated: false)
        }
    }
}

struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data
    @ObservedObject var canvasBridge: CanvasBridge
    let onDrawingChange: (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = EdgeToEdgeCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.alwaysBounceVertical = true
        canvasView.alwaysBounceHorizontal = true
        canvasView.tool = PKInkingTool(.pen, color: .systemBlue, width: 6)
        canvasView.forceEdgeToEdgeLayout()

        if let drawing = try? PKDrawing(data: drawingData) {
            canvasView.drawing = drawing
        }

        canvasBridge.attach(canvasView: canvasView)

        DispatchQueue.main.async {
            canvasView.becomeFirstResponder()
        }

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvasBridge.attach(canvasView: uiView)
        (uiView as? EdgeToEdgeCanvasView)?.forceEdgeToEdgeLayout()

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

        init(parent: DrawingCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.onDrawingChange(canvasView.drawing.dataRepresentation())
        }
    }
}
