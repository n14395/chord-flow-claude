## ChordFlow V1 Plan: Cross-Platform Harmonic Suggestion + MIDI Sequencer (iOS/iPadOS/macOS + AUv3)

### Summary
Build a **Swift/SwiftUI universal app** with a **MIDI-FX-first AUv3 extension** that suggests harmonically compatible notes/chords, lets users arrange sequences in a chord lane timeline, and outputs to other apps via **AUv3 MIDI output**, **CoreMIDI virtual ports**, and **MIDI file export**.

Locked decisions:
- Product mode: **MIDI FX first**
- Theory depth: **practical pop/jazz core**, extensible later
- Business model: **paid one-time**
- OS baseline: **iOS/iPadOS 17+, macOS 14+**
- Sequencer UI: **chord lane + piano-roll hints**
- Host priority: **Logic + AUM**
- Standalone AU hosting: **not in V1**
- Clock model: **host-driven in AU, internal transport in standalone**
- Outputs: **virtual MIDI + MIDI file export**

---

## 1) Product Scope (V1)

### In scope
1. Harmonic suggestion engine:
- Key/scale-aware note and chord suggestions
- Diatonic chords, modal interchange basics, common 7th/9th/11th/13th voicings
- Voice-leading scoring (distance + smoothness)
- Tension controls (simple slider + extension toggles)

2. Arrangement:
- Timeline with chord blocks (start, duration, chord symbol, inversion/voicing preset)
- Per-block note pattern presets (arpeggio/strum/block)
- Global groove/swing + humanize timing/velocity

3. MIDI output:
- AUv3 MIDI effect output to host track/instrument
- Standalone CoreMIDI virtual out port(s)
- Export `.mid` clips/song

4. Platform support:
- Standalone app on iOS/iPadOS/macOS (Catalyst or native AppKit bridge where needed)
- AUv3 extension (MusicEffect/MIDI processor style)

### Out of scope (explicitly deferred)
- Internal hosting of third-party AUv3 instruments/effects in standalone
- Cloud sync/accounts/collaboration
- Subscription/freemium backend
- Advanced reharmonization packs beyond practical core
- Ableton Link (can be post-V1)

---

## 2) Architecture

### Modules
1. `CoreTheory`
- Note, interval, scale, chord, spelling, enharmonic rules
- Chord dictionary + extension/inversion logic

2. `SuggestionEngine`
- Candidate generation from context (key + previous chord + melody note constraints)
- Ranking/scoring pipeline:
  - harmonic fit
  - voice-leading cost
  - tension target
  - stylistic weight profile

3. `SequenceEngine`
- Timeline model (bars/beats/ticks)
- Pattern rendering: chord events -> MIDI note events
- Quantization, swing, humanize
- Deterministic render for offline export

4. `MIDIIO`
- AUv3 MIDI event emission
- CoreMIDI virtual source management
- MIDI clock handling for standalone

5. `AppUI`
- SwiftUI scenes: Suggest, Arrange, Route/Output, Settings
- Host-awareness in AU context (limited UI, host transport dependency)

6. `Persistence`
- Project format (JSON + versioned schema)
- Preset storage (scales, chord sets, pattern presets)

### Runtime boundaries
- **Standalone**: owns transport clock, can start/stop playback, emits to virtual MIDI + local preview (basic built-in click/piano optional only for audition)
- **AUv3**: no independent transport authority; follows host tempo/playhead and emits MIDI aligned to host buffers/timestamps

---

## 3) Public Interfaces / Types

### Internal domain types (stable app-facing contract)
1. `KeyContext { tonic, mode, accidentalPreference }`
2. `ChordToken { root, quality, extensions, alterations, inversion, slashBass? }`
3. `SuggestionRequest { keyContext, previousChord?, melodyHint?, tensionLevel, styleProfile }`
4. `SuggestionResult { chordToken, confidence, reasons[] }`
5. `SequenceBlock { id, barStart, beatStart, lengthBeats, chordToken, patternPreset, velocityProfile }`
6. `ProjectDocument { version, tempo, timeSignature, keyContext, blocks[], routingConfig }`
7. `RoutingConfig { outputMode: auv3|virtualMIDI|both, midiChannelMap, clockMode }`

### AUv3 interface expectations
- AU extension exposes MIDI parameters/events for:
  - key/scale selection
  - complexity/tension
  - pattern style
  - swing/humanize
- Host automation-compatible parameters for core controls
- MIDI output timestamped against host sample time/beat position

### File/export interface
- MIDI file export:
  - Format 1 multitrack optional, default single track
  - PPQ fixed (e.g., 960) for predictable DAW import
- Project schema versioning:
  - `schemaVersion` with migration handlers

---

## 4) UX Plan

### Primary flows
1. Pick key/scale -> receive ranked chord suggestions
2. Tap suggestion -> insert chord block on timeline
3. Adjust durations/patterns/voicings in chord lane
4. Play via host (AU) or standalone transport
5. Route via virtual MIDI or export `.mid`

### Screens
1. **Suggest**
- Scale/key controls
- Suggestion list with confidence + function labels (e.g., ii-V-I role hints)
- “Why this chord” explain panel (compact)

2. **Arrange**
- Horizontal bar timeline with draggable chord blocks
- Piano-roll hint overlay (non-primary, read-first)
- Pattern + groove inspector

3. **Route**
- AU mode state / standalone mode state
- Virtual MIDI destination visibility
- Channel routing and clock settings

4. **Settings**
- Enharmonic preference, latency compensation, default voicings, MIDI export defaults

---

## 5) Implementation Phases

1. **Foundation (2–3 weeks)**
- Domain models, theory primitives, serialization skeleton
- Basic suggestion engine with deterministic unit tests

2. **Sequencer Core (2–3 weeks)**
- Timeline/block engine + MIDI render pipeline
- Swing/humanize + quantization

3. **Standalone MIDI Routing (1–2 weeks)**
- CoreMIDI virtual port creation and real-time emission
- Internal transport + tempo map

4. **AUv3 MIDI Effect (2–3 weeks)**
- Extension target, parameter bridge, host-timestamped MIDI output
- Basic AU UI for key controls + preset recall

5. **UI Polish + Export (2 weeks)**
- Suggest/Arrange/Route screens
- MIDI file export/import checks across Logic/GarageBand/AUM flows

6. **Stability + Store Readiness (2 weeks)**
- Performance profiling, crash hardening, state restoration, migration tests

---

## 6) Testing and Acceptance Criteria

### Automated tests
1. Theory correctness:
- Scale/chord spelling across keys
- Extension/inversion generation

2. Suggestion quality:
- Snapshot tests for canonical progressions (I–V–vi–IV, ii–V–I, modal interchange cases)

3. Render determinism:
- Identical MIDI event streams for identical project seeds/settings

4. AU timing:
- Buffer boundary and tempo-change tests ensuring no dropped/duplicated events

5. Persistence/migration:
- Open old schema versions and verify normalized project reconstruction

### Manual host matrix (priority)
1. Logic Pro (macOS): AU parameter automation, MIDI routing, tempo sync
2. AUM (iOS/iPadOS): AU insertion, routing to external synth apps, transport sync
3. GarageBand: basic AU load + MIDI behavior sanity

### V1 acceptance criteria
1. User can generate and arrange a full 16-bar progression without leaving app
2. AUv3 outputs usable MIDI in host at correct timing for tempo 60–180 BPM
3. Standalone routes live MIDI to at least one external app/device via virtual port
4. Exported MIDI opens with correct chord timing in Logic and GarageBand
5. No data loss on save/reopen across all three platforms

---

## 7) Risks and Mitigations

1. AUv3 timing jitter or host differences
- Mitigation: host-specific timing adapters + regression matrix (Logic/AUM first)

2. Harmony suggestions feel generic
- Mitigation: explicit style profiles + scoring transparency (“why” labels) + curated preset sets

3. Cross-platform UI divergence (macOS vs touch)
- Mitigation: shared SwiftUI core with platform-specific inspector/pointer affordances

4. Scope creep (plugin hosting, advanced reharm)
- Mitigation: hard V1 scope gate; backlog tagged V1.1+

---

## 8) Assumptions and Defaults

1. Language/framework: Swift + SwiftUI + AudioToolbox/CoreMIDI + AUv3 APIs
2. Deployment targets: iOS/iPadOS 17+, macOS 14+
3. Monetization: paid one-time purchase, no account backend
4. No in-app third-party AU hosting in V1
5. V1 quality target emphasizes reliability/integration over deep music-theory edge cases
