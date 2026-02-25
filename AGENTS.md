# AGENTS.md — ChordFlow

## Project Overview

ChordFlow is a Swift/SwiftUI harmonic suggestion + MIDI sequencer app with an AUv3 MIDI FX extension.
Platforms: iOS 17+, macOS 14+ (Mac Catalyst). Two parallel build surfaces exist (see Architecture below).

## Build Commands

### SPM (modular libraries + CLI executable)
```bash
swift build                # Build all SPM targets
swift test                 # Run all SPM tests (4 test targets, Swift Testing framework)
swift test --filter CoreTheoryTests              # Run one test target
swift test --filter CoreTheoryTests/majorScalePitchClasses  # Run single test
```

### Xcode (iOS/macOS app + AUv3 extension)
```bash
# Build the app (includes ChordFlowShared framework + AUv3 extension)
xcodebuild -project Xcode/ChordFlow.xcodeproj -scheme ChordFlowApp \
  -destination "generic/platform=iOS" -quiet build

# Build AUv3 extension only
xcodebuild -project Xcode/ChordFlow.xcodeproj -scheme ChordFlowAUv3 \
  -destination "generic/platform=iOS" -quiet build

# Build the macOS host harness + run its tests
xcodebuild -project Xcode/ChordFlow.xcodeproj -scheme ChordFlowHostHarness \
  -destination "platform=macOS" test
```

### Regenerate Xcode project (after changing targets/settings)
```bash
xcodegen generate --spec Xcode/project.yml
```
The `project.yml` is the source of truth; the `.xcodeproj` is generated. If you edit
build settings, edit `project.yml` and regenerate (or edit `project.pbxproj` directly
if `project.yml` hasn't been kept in sync).

### No linter configured
There is no SwiftLint or SwiftFormat. Follow the conventions below.

## Architecture: Dual Implementation

The codebase has **two parallel implementations** of core domain logic:

| Surface | Location | Used by | Type prefix |
|---------|----------|---------|-------------|
| **SPM** | `Sources/` (7 library targets) | CLI executable, SPM tests | None (`ChordToken`, `KeyContext`) |
| **Xcode Shared** | `Xcode/Shared/` (single framework) | iOS app, AUv3 extension | `CF` prefix (`CFChord`, `CFKeyContext`) |

The Xcode app imports `ChordFlowShared`, **not** the SPM modules. The SPM modules are richer
(extensions, alterations, inversions, slash bass, style profiles); the Xcode types are simpler
(`add7`/`add9` booleans). Do not mix types across the two surfaces.

### SPM module dependency graph
```
ChordFlowModels (leaf)
├── CoreTheory
├── Persistence
├── SuggestionEngine  (also depends on CoreTheory)
├── SequenceEngine    (also depends on CoreTheory)
├── MIDIIO            (also depends on SequenceEngine)
└── AppUI             (depends on SuggestionEngine, SequenceEngine, MIDIIO, Persistence)
```

## Code Style

### Naming
- **Types**: PascalCase nouns. `SequenceBlock`, `ChordToken`, `ProgressionPlaybackEngine`
- **Xcode shared types**: `CF` prefix. `CFChord`, `CFNote`, `CFScaleMode`
- **Functions/methods**: lowerCamelCase, verb-first for actions. `refreshChordButtons()`, `addChord(_:)`
- **Enum cases**: lowerCamelCase. `.major`, `.arpUp`, `.neoSoul`, `.virtualMIDI`
- **Booleans**: `is` prefix. `isPlaying`, `isBorrowed`, `isRunning`
- **Constants**: lowerCamelCase static lets. `ChordFlowEngine.ppq`

### Imports
- SPM files: `Foundation` first, then project modules alphabetically, then platform frameworks
- Xcode files: System frameworks first (`SwiftUI`, `AVFoundation`), then `ChordFlowShared`
- Never use `@testable import` — test only the public API

### Type Preferences
- **Prefer structs** for data and stateless logic. Classes only when reference semantics or
  identity are required (ViewModels, audio engines, CoreMIDI wrappers).
- **All classes must be `final`**. No non-final classes exist in the codebase.
- **Caseless enums** as namespaces for collections of static methods: `TheoryEngine`, `ChordFlowEngine`, `MIDIFileWriter`
- **Data enums** with raw values for categorical types: `NoteName: Int`, `ScaleMode: String`
- **Protocols** are rare — prefer concrete types and static dispatch.

### Protocol Conformances
Declare conformances inline with the type:
```swift
public struct KeyContext: Codable, Sendable, Equatable { ... }
public enum NoteName: Int, Codable, CaseIterable, Sendable { ... }
```
Common sets: model enums get `RawRepresentable, Codable, CaseIterable, Sendable`;
model structs get `Codable, Sendable, Equatable`; add `Identifiable` with `var id: UUID` when needed.

### Access Control
- SPM: explicit `public` on all API types, properties, inits, and methods. `private` on helpers.
- Xcode app-internal: rely on `internal` default. `private` on file-scoped helpers.
- Use `public private(set)` for read-only external properties.

### Error Handling
- Define errors as simple `enum: Error` types (with associated values where needed).
- Propagate with `throws`; handle at the UI boundary with `do/catch` setting a status string.
- Use `try?` only for non-critical operations (audio session setup, engine start).
- No `Result` types — use throwing functions exclusively.

### Init Patterns
- All public struct inits list all parameters with sensible defaults.
- Validate/clamp inside init: `tempo: min(max(tempo, 20), 300)`, `tensionLevel: min(max(tensionLevel, 0), 1)`

### Expression-style Switch (Swift 5.9+)
Preferred for inline value computation:
```swift
let pattern: [Int] = switch key.mode {
case .major: [0, 2, 4, 5, 7, 9, 11]
case .minor: [0, 2, 3, 5, 7, 8, 10]
...
}
```

### File Organization
- `// MARK: -` (with dash) for top-level sections; `// MARK:` (no dash) for subsections.
- Public methods/properties before private within a type.
- SPM: one primary type per module file. Xcode: one concern per file.
- No file header boilerplate (no copyright, author, or date stamps).
- Minimal doc comments (`///`) — use selectively on public engine methods. Inline `//` for intent.

### SwiftUI Conventions
- MVVM: `@MainActor final class: ObservableObject` ViewModel with `@Published` properties.
- Root view owns ViewModel via `@StateObject`; children use `@ObservedObject`.
- Decompose complex views into `private var` computed properties and `private func` helpers.
- Use modern APIs: `NavigationStack`, `.onChange(of:) { _, _ in }`, `.foregroundStyle(.secondary)`.
- Conditional compilation: `#if canImport(SwiftUI)` for cross-context compatibility.

### Concurrency
- **SPM targets**: Swift 6.2 strict concurrency. All types conform to `Sendable`.
- **Xcode targets**: Swift 5 mode (`SWIFT_VERSION: 5.0`). `Sendable` not enforced.
- `@MainActor` on all `ObservableObject` ViewModels and playback engines.
- `NSLock` for thread safety in audio callbacks (not actors — real-time audio thread constraint).
- `DispatchQueue` + `DispatchWorkItem` for scheduled playback events.

## Testing

### SPM tests (Swift Testing framework)
- Test files use `struct`, not `class`.
- Tests annotated with `@Test`, not `func test...()`.
- Assertions use `#expect(...)`, not `XCTAssert`.
- No `@testable` — tests exercise public API only.
```swift
struct CoreTheoryTests {
    @Test func majorScalePitchClasses() {
        let key = KeyContext(tonic: .c, mode: .major)
        #expect(TheoryEngine.scalePitchClasses(for: key) == [0, 2, 4, 5, 7, 9, 11])
    }
}
```

### Xcode tests (XCTest)
- `HostHarnessTests` uses `final class: XCTestCase` with `func test...()` naming and `XCTAssertEqual`.

### Test targets
| Target | Framework | Tests |
|--------|-----------|-------|
| `CoreTheoryTests` | Swift Testing | Scale generation, chord voicing |
| `SuggestionEngineTests` | Swift Testing | Ranked suggestion output |
| `SequenceEngineTests` | Swift Testing | Render determinism |
| `PersistenceTests` | Swift Testing | Encode/decode roundtrip, schema migration |
| `ChordFlowHostHarnessTests` | XCTest | AUv3 fourCC encoding, component description |

## Key File Paths

| File | Purpose |
|------|---------|
| `Sources/ChordFlowModels/Types.swift` | All SPM domain types |
| `Sources/CoreTheory/TheoryEngine.swift` | Scale/chord/voicing primitives |
| `Sources/SuggestionEngine/SuggestionEngine.swift` | Multi-factor chord suggestion scoring |
| `Xcode/Shared/ChordFlowCore.swift` | All Xcode-side domain types (`CF`-prefixed) |
| `Xcode/Shared/ChordFlowEngine.swift` | Xcode-side suggestion, rendering, encoding |
| `Xcode/ChordFlowApp/RootView.swift` | Main app UI (ViewModel + all views) |
| `Xcode/ChordFlowApp/ProgressionPlaybackEngine.swift` | AVAudioEngine sine-wave playback |
| `Xcode/ChordFlowAUv3/ChordFlowMIDIProcessorAudioUnit.swift` | AUv3 MIDI FX audio unit |
| `Xcode/project.yml` | XcodeGen spec (source of truth for Xcode project) |
| `Package.swift` | SPM manifest |
| `PLAN.md` | V1 product/architecture spec |
