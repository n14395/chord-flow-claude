# ChordFlow Xcode Workspace

This folder contains an Xcode project generated with `xcodegen`.

## Targets

- `ChordFlowApp`: iOS app (with Mac Catalyst support)
- `ChordFlowAUv3`: AUv3 MIDI processor extension
- `ChordFlowShared`: shared framework for theory/suggestion/sequence/export logic
- `ChordFlowHostHarness`: macOS host-discovery/test harness executable
- `ChordFlowHostHarnessTests`: harness constant tests (builds in sandbox; execution needs unrestricted testmanagerd access)

## Regenerate project

```bash
xcodegen generate --spec Xcode/project.yml
```

## Build

```bash
xcodebuild -project Xcode/ChordFlow.xcodeproj -scheme ChordFlowApp -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath .xcodebuild CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Xcode/ChordFlow.xcodeproj -scheme ChordFlowHostHarness -configuration Debug -destination 'generic/platform=macOS' -derivedDataPath .xcodebuild build
```

## Run host harness

```bash
./.xcodebuild/Build/Products/Debug/ChordFlowHostHarness
```

## Logic Pro validation workflow

1. Build and run `ChordFlowApp` once on destination (device/simulator as applicable) so AU extension registers.
2. In Logic Pro, insert **ChordFlow MIDI FX** on a software instrument track.
3. Start host transport and verify output follows host tempo/beat.
4. Automate parameters: `Tonic`, `Mode`, `Tension`, `Pattern`, `Swing`, `Humanize`.
5. Confirm MIDI output reaches downstream instrument and remains aligned after tempo changes.

## AUM validation workflow

1. Load ChordFlow AUv3 in a MIDI FX slot.
2. Route its MIDI output to a synth app/channel.
3. Start AUM transport and verify beat-synced chord output.
4. Change tempo and parameter automation and confirm no dropped/jittery note-ons.

## Notes

- `ChordFlowMIDIProcessorAudioUnit` uses a real `AUParameterTree` and reads `musicalContextBlock` + `transportStateBlock` each render cycle.
- The extension emits MIDI via `midiOutputEventBlock` when host transport reports moving state.
