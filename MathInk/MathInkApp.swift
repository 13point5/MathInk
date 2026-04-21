import SwiftData
import SwiftUI

@main
struct MathInkApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [SketchNote.self])
    }
}

