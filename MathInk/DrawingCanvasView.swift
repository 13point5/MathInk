import PencilKit
import SwiftUI

private final class EdgeToEdgeCanvasView: PKCanvasView {
    private let minimumCanvasSide: CGFloat = 6_000
    private let canvasSizeMultiplier: CGFloat = 4.5

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

        isScrollEnabled = true
        alwaysBounceVertical = true
        alwaysBounceHorizontal = true
        bouncesZoom = true
        minimumZoomScale = 0.1
        maximumZoomScale = 4
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false

        let targetContentSize = CGSize(
            width: max(bounds.width * canvasSizeMultiplier, minimumCanvasSide),
            height: max(bounds.height * canvasSizeMultiplier, minimumCanvasSide)
        )

        if contentSize.width < targetContentSize.width || contentSize.height < targetContentSize.height {
            contentSize = CGSize(
                width: max(contentSize.width, targetContentSize.width),
                height: max(contentSize.height, targetContentSize.height)
            )
        }

        if zoomScale < minimumZoomScale || zoomScale > maximumZoomScale {
            setZoomScale(min(max(zoomScale, minimumZoomScale), maximumZoomScale), animated: false)
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
    @Binding var zoomScale: CGFloat
    @Binding var contentOffset: CGPoint
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

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            reportZoomScale(scrollView.zoomScale)
            reportContentOffset(scrollView.contentOffset)
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            reportZoomScale(scale)
            reportContentOffset(scrollView.contentOffset)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            reportContentOffset(scrollView.contentOffset)
        }

        func reportZoomScale(_ scale: CGFloat) {
            guard abs(parent.zoomScale - scale) > 0.001 else { return }
            parent.zoomScale = scale
        }

        func reportContentOffset(_ offset: CGPoint) {
            let deltaX = abs(parent.contentOffset.x - offset.x)
            let deltaY = abs(parent.contentOffset.y - offset.y)
            guard deltaX > 0.25 || deltaY > 0.25 else { return }

            parent.contentOffset = offset
        }
    }
}
