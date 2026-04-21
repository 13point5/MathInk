import PencilKit
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SketchNote.updatedAt, order: .reverse) private var notes: [SketchNote]

    @StateObject private var canvasBridge = CanvasBridge()
    @StateObject private var voiceController = VoiceCommandController()
    @State private var path: [UUID] = []
    @State private var autosaveTask: Task<Void, Never>?
    @State private var didSeed = false
    @State private var typedVoiceCommand = ""
    @State private var renamingNoteID: UUID?
    @State private var renameTitle = ""
    @State private var notePendingDeletionID: UUID?
    @State private var boardZoomScale: CGFloat = 1
    @State private var boardContentOffset: CGPoint = .zero
    @State private var voiceStatusNoteID: UUID?
    @State private var stylePanelWidth: CGFloat = 0
    private let zoomPresetScales: [CGFloat] = [0.1, 0.25, 0.5, 0.75, 1, 2, 4]
    private let voiceToastWidth: CGFloat = 178
    private let voiceToastSpacing: CGFloat = 10

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renamingNoteID != nil },
            set: { isPresented in
                if !isPresented {
                    renamingNoteID = nil
                    renameTitle = ""
                }
            }
        )
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { notePendingDeletionID != nil },
            set: { isPresented in
                if !isPresented {
                    notePendingDeletionID = nil
                }
            }
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            gallery
                .navigationDestination(for: UUID.self) { noteID in
                    if let note = note(for: noteID) {
                        board(for: note)
                    } else {
                        missingBoardView
                    }
                }
        }
        .preferredColorScheme(path.isEmpty ? .dark : .light)
        .task {
            seedStarterNoteIfNeeded()
        }
        .onChange(of: notes.map(\.id)) { _, ids in
            path.removeAll { !ids.contains($0) }
        }
        .onChange(of: path) { _, newPath in
            guard
                let voiceStatusNoteID,
                newPath.last != voiceStatusNoteID
            else {
                return
            }

            clearVoiceStatus()
        }
        .alert("Rename Board", isPresented: renameAlertBinding) {
            TextField("Board Name", text: $renameTitle)
            Button("Cancel", role: .cancel) {}
            Button("Rename", action: commitRename)
        }
        .confirmationDialog(
            "Delete Board?",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: confirmDelete)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var gallery: some View {
        ZStack(alignment: .top) {
            Color.black
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 16) {
                        Text("All Boards")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.cyan)

                        Button(action: createNote) {
                            Image(systemName: "square.and.pencil")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 46, height: 46)
                                .nativeGlassCircle()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("New Board")
                    }

                    if notes.isEmpty {
                        emptyGallery
                    } else {
                        LazyVGrid(columns: galleryColumns, alignment: .leading, spacing: 48) {
                            ForEach(notes) { note in
                                NavigationLink(value: note.id) {
                                    BoardCard(note: note)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    boardActions(for: note)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)
                .padding(.bottom, 56)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var galleryColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 250, maximum: 330),
                spacing: 56,
                alignment: .top
            )
        ]
    }

    private var emptyGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No Boards")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text("Create a board to start sketching.")
                .foregroundStyle(.white.opacity(0.62))
        }
        .padding(.top, 16)
    }

    private func board(for note: SketchNote) -> some View {
        ZStack(alignment: .top) {
            DotGridView(
                zoomScale: boardZoomScale,
                contentOffset: boardContentOffset
            )
                .ignoresSafeArea()

            DrawingCanvasView(
                drawingData: Binding(
                    get: { note.drawingData },
                    set: { updateDrawing(for: note, with: $0) }
                ),
                zoomScale: $boardZoomScale,
                contentOffset: $boardContentOffset,
                canvasBridge: canvasBridge
            ) { updatedData in
                updateDrawing(for: note, with: updatedData)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .onPencilDoubleTap { _ in
                toggleVoiceListening(for: note, trigger: "Apple Pencil double tap")
            }
            .onPencilSqueeze { phase in
                guard case .ended = phase else { return }

                toggleVoiceListening(for: note, trigger: "Apple Pencil squeeze")
            }

            boardBottomControls(for: note)

            boardTopBar(for: note)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Color.white)
        .environment(\.colorScheme, .light)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            boardZoomScale = 1
            boardContentOffset = .zero
        }
    }

    private var missingBoardView: some View {
        ContentUnavailableView(
            "Board Not Found",
            systemImage: "square.dashed",
            description: Text("Return to all boards and choose another sketch.")
        )
        .toolbar(.hidden, for: .navigationBar)
    }

    private func boardTopBar(for note: SketchNote) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                BoardBackButton {
                    path.removeAll()
                }

                Menu {
                    boardActions(for: note)
                } label: {
                    HStack(spacing: 7) {
                        Text(note.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Image(systemName: "chevron.down.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 10)
                    .frame(height: 44)
                    .nativeGlassCapsule()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Board Options")
                .frame(maxWidth: 300, alignment: .leading)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)

            Spacer()
        }
    }

    @ViewBuilder
    private func boardActions(for note: SketchNote) -> some View {
        Button {
            openRename(for: note)
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Button {
            duplicate(note)
        } label: {
            Label("Duplicate", systemImage: "square.on.square")
        }

        Divider()

        Button(role: .destructive) {
            requestDelete(note)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func shouldShowVoiceToast(for note: SketchNote) -> Bool {
        voiceStatusNoteID == note.id && voiceController.isStatusVisible
    }

    private func boardBottomControls(for note: SketchNote) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            GeometryReader { proxy in
                let toastSlotWidth = voiceToastSlotWidth(for: proxy.size.width)
                let toastSpacing = toastSlotWidth > 0 ? voiceToastSpacing : 0

                ZStack {
                    HStack(spacing: toastSpacing) {
                        Color.clear
                            .frame(width: toastSlotWidth)
                            .allowsHitTesting(false)

                        StylePanel(
                            canvasBridge: canvasBridge,
                            isListening: voiceStatusNoteID == note.id && voiceController.isListening,
                            audioLevels: voiceStatusNoteID == note.id ? voiceController.audioLevels : [],
                            startListening: {
                                toggleVoiceListening(for: note, trigger: "the style panel mic")
                            }
                        )
                        .fixedSize()
                        .measuredWidth($stylePanelWidth)

                        if shouldShowVoiceToast(for: note), toastSlotWidth > 0 {
                            voiceToast(for: note, width: toastSlotWidth)
                                .transition(.opacity)
                        } else {
                            Color.clear
                                .frame(width: toastSlotWidth)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .animation(.easeOut(duration: 0.16), value: shouldShowVoiceToast(for: note))

                    zoomLevelBadge
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 0)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            }
            .frame(height: 76)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func voiceToastSlotWidth(for availableWidth: CGFloat) -> CGFloat {
        guard stylePanelWidth > 0 else { return voiceToastWidth }

        let trailingSpace = (availableWidth - stylePanelWidth) / 2 - voiceToastSpacing - 14
        return min(voiceToastWidth, max(trailingSpace, 0))
    }

    private var zoomLevelBadge: some View {
        Menu {
            Button(action: zoomToFitContent) {
                Label("Zoom to Fit Content", systemImage: "arrow.up.left.and.arrow.down.right")
            }

            Divider()

            ForEach(zoomPresetScales, id: \.self) { scale in
                Button {
                    setBoardZoom(scale)
                } label: {
                    if isCurrentZoom(scale) {
                        Label(zoomTitle(for: scale), systemImage: "checkmark")
                    } else {
                        Text(zoomTitle(for: scale))
                    }
                }
            }
        } label: {
            Text(zoomTitle(for: boardZoomScale))
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .nativeGlassCapsule()
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Zoom \(zoomTitle(for: boardZoomScale))")
    }

    private func voiceToast(for note: SketchNote, width: CGFloat) -> some View {
        #if targetEnvironment(simulator)
        voiceToastContent(for: note, width: width)
        #else
        voiceToastContent(for: note, width: width)
            .allowsHitTesting(false)
        #endif
    }

    private func voiceToastContent(for note: SketchNote, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: voiceController.isListening ? "waveform" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(voiceController.isListening ? .blue : .green)

                Text(voiceToastTitle)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            if !voiceController.transcript.isEmpty {
                Text(voiceController.transcript)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            #if targetEnvironment(simulator)
            if !voiceController.isListening {
                HStack(spacing: 6) {
                    TextField("Type command", text: $typedVoiceCommand)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onSubmit {
                            applyTypedVoiceCommand(for: note)
                        }

                    Button("Apply") {
                        applyTypedVoiceCommand(for: note)
                    }
                    .font(.caption)
                    .disabled(typedVoiceCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            #endif
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: width, alignment: .leading)
        .nativeGlassRoundedRectangle(cornerRadius: 16)
    }

    private var voiceToastTitle: String {
        if voiceController.isListening {
            if voiceController.transcript.isEmpty {
                return "Listening..."
            }

            return "Recognizing"
        }

        return voiceController.statusMessage
    }

    private func toggleVoiceListening(for note: SketchNote, trigger: String) {
        voiceStatusNoteID = note.id
        voiceController.onCommand = { command in
            canvasBridge.apply(command: command)
        }

        Task {
            await voiceController.toggleListening(trigger: trigger)
        }
    }

    private func clearVoiceStatus() {
        voiceController.onCommand = nil
        voiceController.clearStatus()
        voiceStatusNoteID = nil
        typedVoiceCommand = ""
    }

    private func applyTypedVoiceCommand(for note: SketchNote) {
        voiceStatusNoteID = note.id

        let commandText = typedVoiceCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commandText.isEmpty else { return }

        if let command = InkCommand.parse(commandText) {
            canvasBridge.apply(command: command)
            voiceController.transcript = commandText
            voiceController.showSimulatorFallbackStatus("Applied \(command.displayName) from the typed Simulator fallback.")
            typedVoiceCommand = ""
        } else {
            voiceController.transcript = commandText
            voiceController.showSimulatorFallbackStatus("Could not parse \"\(commandText)\".")
        }
    }

    private func note(for id: UUID) -> SketchNote? {
        notes.first(where: { $0.id == id })
    }

    private func seedStarterNoteIfNeeded() {
        guard !didSeed else { return }
        didSeed = true

        if notes.isEmpty {
            let starter = SketchNote(title: "Untitled 1")
            modelContext.insert(starter)
            try? modelContext.save()
        }
    }

    private func createNote() {
        let note = SketchNote(title: "Untitled \(notes.count + 1)")
        modelContext.insert(note)
        try? modelContext.save()
        path = [note.id]
    }

    private func openRename(for note: SketchNote) {
        renameTitle = note.title
        renamingNoteID = note.id
    }

    private func commitRename() {
        let trimmedTitle = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let renamingNoteID, !trimmedTitle.isEmpty, let note = note(for: renamingNoteID) else {
            return
        }

        note.title = trimmedTitle
        note.updatedAt = .now
        try? modelContext.save()
        self.renamingNoteID = nil
        renameTitle = ""
    }

    private func duplicate(_ note: SketchNote) {
        let copy = SketchNote(
            title: "\(note.title) Copy",
            drawingData: note.drawingData
        )
        modelContext.insert(copy)
        try? modelContext.save()
        path = [copy.id]
    }

    private func requestDelete(_ note: SketchNote) {
        notePendingDeletionID = note.id
    }

    private func confirmDelete() {
        guard let notePendingDeletionID, let note = note(for: notePendingDeletionID) else {
            return
        }

        path.removeAll { $0 == notePendingDeletionID }
        modelContext.delete(note)
        try? modelContext.save()
        self.notePendingDeletionID = nil
    }

    private func updateDrawing(for note: SketchNote, with data: Data) {
        guard note.drawingData != data else { return }

        note.drawingData = data
        note.updatedAt = .now

        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            try? modelContext.save()
        }
    }

    private func setBoardZoom(_ scale: CGFloat) {
        boardZoomScale = canvasBridge.setZoomScale(scale) ?? scale
    }

    private func zoomToFitContent() {
        if let fittedScale = canvasBridge.zoomToFitContent() {
            boardZoomScale = fittedScale
        }
    }

    private func zoomTitle(for scale: CGFloat) -> String {
        "\(Int((scale * 100).rounded()))%"
    }

    private func isCurrentZoom(_ scale: CGFloat) -> Bool {
        abs(boardZoomScale - scale) < 0.01
    }
}

private struct BoardCard: View {
    let note: SketchNote

    var body: some View {
        VStack(spacing: 0) {
            BoardThumbnail(drawingData: note.drawingData)
                .aspectRatio(16 / 9, contentMode: .fit)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(note.updatedAt, format: .dateTime.month().day().year().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(white: 0.11))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct BoardThumbnail: View {
    let drawingData: Data

    var body: some View {
        ZStack {
            Color.white

            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            }
        }
    }

    private var thumbnailImage: UIImage? {
        guard
            let drawing = try? PKDrawing(data: drawingData),
            !drawing.bounds.isEmpty
        else {
            return nil
        }

        let bounds = drawing.bounds.insetBy(dx: -80, dy: -80)
        return drawing.image(from: bounds, scale: UIScreen.main.scale)
    }
}

private struct DotGridView: View {
    let zoomScale: CGFloat
    let contentOffset: CGPoint

    var body: some View {
        Canvas { context, size in
            let baseSpacing: CGFloat = 32
            let gridOrigin = CGPoint(x: 8, y: 4)
            let zoom = max(zoomScale, 0.001)
            let logicalSpacing = gridSpacing(for: zoom, baseSpacing: baseSpacing)
            let screenSpacing = logicalSpacing * zoom
            let dotSize = min(max(2.2 * sqrt(zoom), 0.9), 3.4)
            let dotColor = Color(white: 0.72)
            let firstX = positiveRemainder(gridOrigin.x * zoom - contentOffset.x, dividedBy: screenSpacing)
            let firstY = positiveRemainder(gridOrigin.y * zoom - contentOffset.y, dividedBy: screenSpacing)

            for x in stride(from: firstX, through: size.width + screenSpacing, by: screenSpacing) {
                for y in stride(from: firstY, through: size.height + screenSpacing, by: screenSpacing) {
                    let rect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                }
            }
        }
        .background(Color.white)
    }

    private func gridSpacing(for zoom: CGFloat, baseSpacing: CGFloat) -> CGFloat {
        var spacing = baseSpacing

        while spacing * zoom < 12 {
            spacing *= 2
        }

        return spacing
    }

    private func positiveRemainder(_ value: CGFloat, dividedBy divisor: CGFloat) -> CGFloat {
        guard divisor > 0 else { return 0 }

        let remainder = value.truncatingRemainder(dividingBy: divisor)
        return remainder >= 0 ? remainder : remainder + divisor
    }
}

private struct CircleIconButton: View {
    let systemName: String
    var foregroundStyle: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(foregroundStyle)
                .frame(width: 52, height: 52)
                .nativeGlassCircle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName)
    }
}

private struct BoardBackButton: View {
    @Environment(\.dismiss) private var dismiss
    let fallback: () -> Void

    var body: some View {
        Button {
            dismiss()
            fallback()
        } label: {
            Image(systemName: "chevron.left")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .nativeGlassCircle()
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("All Boards")
    }
}

private struct WidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    func measuredWidth(_ width: Binding<CGFloat>) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: WidthPreferenceKey.self, value: proxy.size.width)
            }
        }
        .onPreferenceChange(WidthPreferenceKey.self) { newWidth in
            width.wrappedValue = newWidth
        }
    }

    @ViewBuilder
    func nativeGlassCircle() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: Circle())
        } else {
            background(.ultraThinMaterial, in: Circle())
        }
    }

    @ViewBuilder
    func nativeGlassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: Capsule())
        } else {
            background(.ultraThinMaterial, in: Capsule())
        }
    }

    @ViewBuilder
    func nativeGlassRoundedRectangle(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }
}
