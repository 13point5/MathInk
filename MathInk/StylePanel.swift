import SwiftUI

struct StylePanel: View {
    @ObservedObject var canvasBridge: CanvasBridge
    let startListening: () -> Void

    private let toolChoices: [InkCommand.ToolKind] = [.pen, .pencil, .marker, .eraser]
    private let colorChoices: [InkCommand.NamedColor] = [.black, .blue, .green, .yellow, .orange, .red, .purple]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(toolChoices, id: \.self) { tool in
                Button {
                    performWithoutToolbarAnimation {
                        canvasBridge.selectTool(tool)
                    }
                } label: {
                    ToolChip(
                        tool: tool,
                        color: canvasBridge.rememberedColor(for: tool),
                        isSelected: canvasBridge.selectedCommand.tool == tool
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(toolAccessibilityLabel(for: tool))
            }

            Divider()
                .frame(height: 30)

            ForEach(colorChoices, id: \.self) { color in
                Button {
                    performWithoutToolbarAnimation {
                        canvasBridge.selectColor(color)
                    }
                } label: {
                    ColorChip(
                        color: color,
                        isSelected: canvasBridge.selectedCommand.color == color && canvasBridge.selectedCommand.tool != .eraser
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.rawValue.capitalized)
            }

            Divider()
                .frame(height: 30)

            Button(action: startListening) {
                Label("Voice", systemImage: "mic.fill")
                    .labelStyle(.iconOnly)
                    .font(.body)
                    .frame(width: 36, height: 36)
                    .background(.blue.opacity(0.16), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voice Tool")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .stylePanelGlass()
        .animation(nil, value: canvasBridge.selectedCommand)
    }
}

private struct ToolChip: View {
    let tool: InkCommand.ToolKind
    let color: InkCommand.NamedColor?
    let isSelected: Bool
    @State private var selectionPulse = false

    var body: some View {
        ZStack {
            Image(systemName: symbolName)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(chipBackground, in: Circle())
                .overlay {
                    Circle()
                        .stroke(chipRingColor, lineWidth: chipRingWidth)
                }
        }
        .transaction { transaction in
            transaction.disablesAnimations = true
            transaction.animation = nil
        }
        .frame(width: 40, height: 40)
        .scaleEffect(selectionPulse ? 1.08 : 1)
        .animation(.spring(response: 0.18, dampingFraction: 0.62), value: selectionPulse)
        .onChange(of: isSelected) { _, newValue in
            guard newValue else {
                selectionPulse = false
                return
            }

            pulseSelection()
        }
    }

    private var symbolName: String {
        switch tool {
        case .pen:
            return "pencil.tip"
        case .pencil:
            return "applepencil"
        case .marker:
            return "highlighter"
        case .eraser:
            return "eraser"
        }
    }

    private var chipBackground: Color {
        guard let color else {
            return isSelected ? .primary.opacity(0.12) : Color(uiColor: .secondarySystemBackground)
        }

        return Color(uiColor: color.uiColor).opacity(isSelected ? 0.24 : 0.1)
    }

    private var chipRingColor: Color {
        guard let color else {
            return isSelected ? .primary.opacity(0.7) : .clear
        }

        return Color(uiColor: color.uiColor).opacity(isSelected ? 0.95 : 0.56)
    }

    private var chipRingWidth: CGFloat {
        guard color != nil else {
            return isSelected ? 2.5 : 0
        }

        return isSelected ? 3 : 1.5
    }

    private func pulseSelection() {
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            selectionPulse = false
        }

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.62)) {
                selectionPulse = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                    selectionPulse = false
                }
            }
        }
    }
}

private struct ColorChip: View {
    let color: InkCommand.NamedColor
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(Color(uiColor: color.uiColor))
            .frame(width: 28, height: 28)
            .overlay {
                Circle()
                    .stroke(.primary.opacity(isSelected ? 0.9 : 0), lineWidth: 3)
                    .padding(-5)
            }
            .transaction { transaction in
                transaction.disablesAnimations = true
                transaction.animation = nil
            }
    }
}

private extension View {
    @ViewBuilder
    func stylePanelGlass() -> some View {
        if #available(iOS 26.0, *) {
            background {
                Capsule()
                    .fill(Color.clear)
                    .glassEffect(.regular, in: Capsule())
            }
                .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
        } else {
            background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
        }
    }
}

private extension StylePanel {
    func performWithoutToolbarAnimation(_ action: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        transaction.animation = nil

        withTransaction(transaction, action)
    }

    func toolAccessibilityLabel(for tool: InkCommand.ToolKind) -> String {
        guard let color = canvasBridge.rememberedColor(for: tool) else {
            return tool.rawValue.capitalized
        }

        return "\(color.rawValue.capitalized) \(tool.rawValue.capitalized)"
    }
}
