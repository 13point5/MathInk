import Foundation
import SwiftData

@Model
final class SketchNote {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    @Attribute(.externalStorage) var drawingData: Data

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        drawingData: Data = Data()
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.drawingData = drawingData
    }
}

