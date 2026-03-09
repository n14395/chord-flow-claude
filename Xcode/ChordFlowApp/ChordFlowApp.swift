import SwiftUI
import UniformTypeIdentifiers

// MARK: - Custom UTType

extension UTType {
    static let chordFlowProject = UTType(exportedAs: "com.n14395.chordflow2.project")
}

// MARK: - App

@main
struct ChordFlowAppMain: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
