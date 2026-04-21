import Foundation
import PencilKit
import UIKit

struct InkCommand: Equatable, Sendable {
    enum ToolKind: String, Equatable, Sendable {
        case pen
        case pencil
        case marker
        case eraser
    }

    enum NamedColor: String, CaseIterable, Equatable, Sendable {
        case black
        case blue
        case green
        case orange
        case purple
        case red
        case yellow

        var uiColor: UIColor {
            switch self {
            case .black:
                return .black
            case .blue:
                return .systemBlue
            case .green:
                return .systemGreen
            case .orange:
                return .systemOrange
            case .purple:
                return .systemPurple
            case .red:
                return .systemRed
            case .yellow:
                return .systemYellow
            }
        }
    }

    let tool: ToolKind
    let color: NamedColor?

    var displayName: String {
        guard let color else {
            return tool.rawValue.capitalized
        }

        return "\(color.rawValue.capitalized) \(tool.rawValue.capitalized)"
    }

    func makePKTool() -> PKTool {
        switch tool {
        case .pen:
            return PKInkingTool(.pen, color: color?.uiColor ?? .systemBlue, width: 6)
        case .pencil:
            return PKInkingTool(.pencil, color: color?.uiColor ?? .darkGray, width: 5)
        case .marker:
            return PKInkingTool(.marker, color: color?.uiColor ?? .systemYellow, width: 18)
        case .eraser:
            return PKEraserTool(.vector)
        }
    }

    static func parse(_ transcript: String) -> InkCommand? {
        let normalized = transcript
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")

        if normalized.contains("eraser") || normalized.contains("erase") {
            return InkCommand(tool: .eraser, color: nil)
        }

        guard let color = NamedColor.allCases.first(where: { normalized.contains($0.rawValue) }) else {
            return nil
        }

        if normalized.contains("marker") || normalized.contains("highlighter") {
            return InkCommand(tool: .marker, color: color)
        }

        if normalized.contains("pencil") {
            return InkCommand(tool: .pencil, color: color)
        }

        if normalized.contains("pen") || normalized.contains("ink") {
            return InkCommand(tool: .pen, color: color)
        }

        return nil
    }
}
