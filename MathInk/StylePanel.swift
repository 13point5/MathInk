import SwiftUI

struct StylePanel: View {
    @ObservedObject var canvasBridge: CanvasBridge
    let startListening: () -> Void

    private let toolChoices: [InkCommand.ToolKind] = [.pen, .pencil, .marker, .eraser]
    private let colorChoices: [InkCommand.NamedColor] = [.black, .blue, .green, .yellow, .red, .purple]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(toolChoices, id: \.self) { tool in
                Button {
                    canvasBridge.selectTool(tool)
                } label: {
                    ToolChip(
                        tool: tool,
                        isSelected: canvasBridge.selectedCommand.tool == tool
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tool.rawValue.capitalized)
            }

            Divider()
                .frame(height: 36)

            ForEach(colorChoices, id: \.self) { color in
                Button {
                    canvasBridge.selectColor(color)
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
                .frame(height: 36)

            Button(action: startListening) {
                Label("Voice", systemImage: "mic.fill")
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(.blue.opacity(0.16), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voice Tool")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
    }
}

private struct ToolChip: View {
    let tool: InkCommand.ToolKind
    let isSelected: Bool

    var body: some View {
        Image(systemName: symbolName)
            .font(.title3)
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(width: 44, height: 44)
            .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemBackground), in: Circle())
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
}

private struct ColorChip: View {
    let color: InkCommand.NamedColor
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(Color(uiColor: color.uiColor))
            .frame(width: 34, height: 34)
            .overlay {
                Circle()
                    .stroke(.primary.opacity(isSelected ? 0.9 : 0), lineWidth: 3)
                    .padding(-5)
            }
    }
}

