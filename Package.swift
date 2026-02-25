// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "chord-progressions",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ChordFlowModels", targets: ["ChordFlowModels"]),
        .library(name: "CoreTheory", targets: ["CoreTheory"]),
        .library(name: "SuggestionEngine", targets: ["SuggestionEngine"]),
        .library(name: "SequenceEngine", targets: ["SequenceEngine"]),
        .library(name: "MIDIIO", targets: ["MIDIIO"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "AppUI", targets: ["AppUI"]),
        .executable(name: "chord-progressions", targets: ["chord-progressions"])
    ],
    targets: [
        .target(name: "ChordFlowModels"),
        .target(
            name: "CoreTheory",
            dependencies: ["ChordFlowModels"]
        ),
        .target(
            name: "SuggestionEngine",
            dependencies: ["ChordFlowModels", "CoreTheory"]
        ),
        .target(
            name: "SequenceEngine",
            dependencies: ["ChordFlowModels", "CoreTheory"]
        ),
        .target(
            name: "MIDIIO",
            dependencies: ["ChordFlowModels", "SequenceEngine"]
        ),
        .target(
            name: "Persistence",
            dependencies: ["ChordFlowModels"]
        ),
        .target(
            name: "AppUI",
            dependencies: ["ChordFlowModels", "SuggestionEngine", "SequenceEngine", "MIDIIO", "Persistence"]
        ),
        .executableTarget(
            name: "chord-progressions",
            dependencies: ["ChordFlowModels", "CoreTheory", "SuggestionEngine", "SequenceEngine", "MIDIIO", "Persistence"]
        ),
        .testTarget(
            name: "CoreTheoryTests",
            dependencies: ["CoreTheory", "ChordFlowModels"]
        ),
        .testTarget(
            name: "SuggestionEngineTests",
            dependencies: ["SuggestionEngine", "CoreTheory", "ChordFlowModels"]
        ),
        .testTarget(
            name: "SequenceEngineTests",
            dependencies: ["SequenceEngine", "ChordFlowModels"]
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: ["Persistence", "ChordFlowModels"]
        )
    ]
)
