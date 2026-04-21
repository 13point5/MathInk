import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SketchNote.updatedAt, order: .reverse) private var notes: [SketchNote]

    @StateObject private var canvasBridge = CanvasBridge()
    @StateObject private var voiceController = VoiceCommandController()
    @AppStorage("MathInk.sidebarVisibility") private var storedSidebarVisibility = "all"
    @State private var columnVisibility: NavigationSplitViewVisibility
    @State private var selectedNoteID: UUID?
    @State private var autosaveTask: Task<Void, Never>?
    @State private var didSeed = false
    @State private var typedVoiceCommand = ""

    init() {
        let storedVisibility = UserDefaults.standard.string(forKey: "MathInk.sidebarVisibility") ?? "all"
        _columnVisibility = State(initialValue: storedVisibility == "detailOnly" ? .detailOnly : .all)
    }

    private var selectedNote: SketchNote? {
        notes.first(where: { $0.id == selectedNoteID })
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedNoteID) {
                ForEach(notes) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.title)
                            .font(.headline)
                        Text(note.updatedAt, format: .dateTime.month().day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .tag(note.id)
                }
                .onDelete(perform: deleteNotes)
            }
            .navigationTitle("MathInk")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: createNote) {
                        Label("New Sketch", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let note = selectedNote {
                editor(for: note)
            } else {
                ContentUnavailableView(
                    "No Sketch Selected",
                    systemImage: "scribble.variable",
                    description: Text("Create a sketch from the sidebar to start drawing.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
                .ignoresSafeArea()
            }
        }
        .task {
            seedStarterNoteIfNeeded()
            voiceController.onCommand = { command in
                canvasBridge.apply(command: command)
            }
        }
        .onChange(of: columnVisibility) { _, newValue in
            storedSidebarVisibility = newValue == .detailOnly ? "detailOnly" : "all"
        }
        .onChange(of: notes.map(\.id)) { _, ids in
            guard selectedNoteID == nil || ids.contains(selectedNoteID!) else {
                selectedNoteID = ids.first
                return
            }

            if selectedNoteID == nil {
                selectedNoteID = ids.first
            }
        }
    }

    private func editor(for note: SketchNote) -> some View {
        ZStack(alignment: .topLeading) {
            DrawingCanvasView(
                drawingData: Binding(
                    get: { note.drawingData },
                    set: { updateDrawing(for: note, with: $0) }
                ),
                canvasBridge: canvasBridge
            ) { updatedData in
                updateDrawing(for: note, with: updatedData)
            }
            .background(Color(uiColor: .systemBackground))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                StylePanel(
                    canvasBridge: canvasBridge,
                    startListening: {
                        Task {
                            await voiceController.toggleListening(trigger: "the style panel mic")
                        }
                    }
                )
                .padding(.bottom, 24)
            }
            .onPencilDoubleTap { _ in
                Task {
                    await voiceController.toggleListening(trigger: "Apple Pencil double tap")
                }
            }
            .onPencilSqueeze { phase in
                guard case .ended = phase else { return }

                Task {
                    await voiceController.toggleListening(trigger: "Apple Pencil squeeze")
                }
            }

            floatingStatusPanel
                .padding(.horizontal, 24)
                .padding(.top, 128)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .ignoresSafeArea()
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var floatingStatusPanel: some View {
        #if targetEnvironment(simulator)
        statusPanel
        #else
        statusPanel
            .allowsHitTesting(false)
        #endif
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                voiceController.statusMessage,
                systemImage: voiceController.isListening ? "waveform" : "sparkles"
            )
            .font(.callout)
            .foregroundStyle(voiceController.isListening ? .primary : .secondary)

            if !voiceController.transcript.isEmpty {
                Text("Heard: \(voiceController.transcript)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            #if targetEnvironment(simulator)
            HStack(spacing: 8) {
                TextField("Simulator fallback: type red pen, blue pencil, yellow marker, or eraser", text: $typedVoiceCommand)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(applyTypedVoiceCommand)

                Button("Apply", action: applyTypedVoiceCommand)
                    .disabled(typedVoiceCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func seedStarterNoteIfNeeded() {
        guard !didSeed else { return }
        didSeed = true

        if notes.isEmpty {
            let starter = SketchNote(title: "My First Sketch")
            modelContext.insert(starter)
            selectedNoteID = starter.id
            try? modelContext.save()
        } else if selectedNoteID == nil {
            selectedNoteID = notes.first?.id
        }
    }

    private func createNote() {
        let note = SketchNote(title: "Sketch \(notes.count + 1)")
        modelContext.insert(note)
        selectedNoteID = note.id
        try? modelContext.save()
    }

    private func deleteNotes(at offsets: IndexSet) {
        let idsToDelete = offsets.map { notes[$0].id }
        let remainingID = notes
            .map(\.id)
            .first(where: { !idsToDelete.contains($0) })

        offsets.forEach { index in
            modelContext.delete(notes[index])
        }

        try? modelContext.save()

        if let selectedNoteID, idsToDelete.contains(selectedNoteID) {
            self.selectedNoteID = remainingID
        }
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

    private func applyTypedVoiceCommand() {
        let commandText = typedVoiceCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commandText.isEmpty else { return }

        if let command = InkCommand.parse(commandText) {
            canvasBridge.apply(command: command)
            voiceController.transcript = commandText
            voiceController.statusMessage = "Applied \(command.displayName) from the typed Simulator fallback."
            typedVoiceCommand = ""
        } else {
            voiceController.transcript = commandText
            voiceController.statusMessage = "Could not parse \"\(commandText)\". Try red pen, blue pencil, yellow marker, or eraser."
        }
    }
}
