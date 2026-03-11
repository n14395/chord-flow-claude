#if canImport(SwiftUI)
import SwiftUI

// MARK: - Help Guide

public struct SharedHelpView: View {
    var onDismiss: () -> Void

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CFSpacing.spacious) {
                // Header
                VStack(alignment: .leading, spacing: CFSpacing.tight) {
                    Text("ChordFlow Guide")
                        .font(.cfDisplay)
                        .foregroundStyle(Color.cfTextPrimary)
                    Text("Learn how the app works and what everything means.")
                        .font(.cfBody)
                        .foregroundStyle(Color.cfTextSecondary)
                }
                .padding(.bottom, CFSpacing.tight)

                helpSection(
                    icon: "circle.grid.cross",
                    title: "The Circle of Fifths",
                    content: circleOfFifthsContent
                )

                helpSection(
                    icon: "paintpalette",
                    title: "Harmonic Functions & Colors",
                    content: harmonicFunctionsContent
                )

                helpSection(
                    icon: "pianokeys",
                    title: "Compose Tab",
                    content: composeTabContent
                )

                helpSection(
                    icon: "sparkles",
                    title: "Suggest Tab & How Suggestions Work",
                    content: suggestTabContent
                )

                helpSection(
                    icon: "rectangle.split.3x1",
                    title: "The Timeline",
                    content: timelineContent
                )

                helpSection(
                    icon: "slider.horizontal.3",
                    title: "Chord Detail Editing",
                    content: chordDetailContent
                )

                helpSection(
                    icon: "arrow.triangle.branch",
                    title: "Borrowed Chords",
                    content: borrowedChordsContent
                )

                helpSection(
                    icon: "dial.low",
                    title: "Tension & Extensions",
                    content: tensionContent
                )

                helpSection(
                    icon: "play.circle",
                    title: "Playback & MIDI Output",
                    content: playbackContent
                )

                helpSection(
                    icon: "doc",
                    title: "Files, Projects & MIDI Export",
                    content: filesContent
                )

                // Dismiss button
                Button(action: onDismiss) {
                    Text("Got it")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.cfBase)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CFSpacing.compact)
                        .background(Capsule().fill(Color.cfTonic))
                }
                .buttonStyle(.plain)
                .padding(.top, CFSpacing.standard)

                // Footer
                Text("Tap the ? button anytime to revisit this guide.")
                    .font(.cfCaption)
                    .foregroundStyle(Color.cfTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, CFSpacing.section)
            }
            .padding(.horizontal, CFSpacing.spacious)
            .padding(.top, CFSpacing.spacious)
        }
        .background(Color.cfBackground.ignoresSafeArea())
    }

    // MARK: - Section Builder

    private func helpSection(icon: String, title: String, content: [HelpParagraph]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: CFSpacing.standard) {
                    ForEach(content.indices, id: \.self) { i in
                        content[i].view
                    }
                }
                .padding(.top, CFSpacing.compact)
                .padding(.bottom, CFSpacing.standard)
            } label: {
                Label {
                    Text(title)
                        .font(.cfHeading)
                        .foregroundStyle(Color.cfTextPrimary)
                } icon: {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.cfTonic)
                        .frame(width: 24)
                }
            }
            .tint(Color.cfTextTertiary)
            .padding(.horizontal, CFSpacing.standard)
            .padding(.vertical, CFSpacing.compact)
        }
        .background(
            RoundedRectangle(cornerRadius: CFRadius.card)
                .fill(Color.cfSurface)
                .strokeBorder(Color.cfBorder, lineWidth: 1)
        )
    }

    // MARK: - Content Helpers

    private struct HelpParagraph {
        let view: AnyView

        static func text(_ string: String) -> HelpParagraph {
            HelpParagraph(view: AnyView(
                Text(string)
                    .font(.cfBody)
                    .foregroundStyle(Color.cfTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            ))
        }

        static func bullet(_ string: String) -> HelpParagraph {
            HelpParagraph(view: AnyView(
                HStack(alignment: .top, spacing: CFSpacing.tight) {
                    Text("\u{2022}")
                        .font(.cfBody)
                        .foregroundStyle(Color.cfTextTertiary)
                    Text(string)
                        .font(.cfBody)
                        .foregroundStyle(Color.cfTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, CFSpacing.tight)
            ))
        }

        static func colorLabel(_ label: String, color: Color, description: String) -> HelpParagraph {
            HelpParagraph(view: AnyView(
                HStack(spacing: CFSpacing.tight) {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                    Text(label)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(color)
                    Text("-- \(description)")
                        .font(.cfBody)
                        .foregroundStyle(Color.cfTextSecondary)
                }
                .padding(.leading, CFSpacing.tight)
            ))
        }
    }

    // MARK: - Section Content

    private var circleOfFifthsContent: [HelpParagraph] {
        [
            .text("The large circle in the center of the Compose and Suggest tabs arranges all 12 musical notes in circle-of-fifths order, not chromatic order (C-C#-D...). Each note is a perfect fifth (7 semitones) clockwise from the previous one."),
            .text("This layout is chosen because notes that are adjacent on the circle are harmonically close -- moving by a fourth or fifth is the most natural chord progression in tonal music. It also means all 7 diatonic chords in any key cluster together in a contiguous arc."),
            .bullet("Outer ring: All 12 chromatic notes. The current key's tonic is highlighted with a glow. Tap any note to change key."),
            .bullet("Inner ring: The 7 diatonic chords for the current key, positioned at their root's location on the circle. Tap to preview, tap + to add to the timeline."),
            .bullet("Outermost ring (dashed): Borrowed chords from parallel modes, shown with pink dashed borders."),
            .bullet("Center label: Shows the current key and mode (e.g. \"C / Major\"). Tap it to change the scale mode."),
        ]
    }

    private var harmonicFunctionsContent: [HelpParagraph] {
        [
            .text("Each chord is colored by its harmonic function -- its role in creating tension and resolution:"),
            .colorLabel("Tonic (I, iii, vi)", color: .cfTonic, description: "home, stable, resolved"),
            .colorLabel("Subdominant (ii, IV)", color: .cfSubdominant, description: "movement, departure"),
            .colorLabel("Dominant (V, vii\u{00B0})", color: .cfDominant, description: "tension, pull back to tonic"),
            .colorLabel("Borrowed", color: .cfBorrowed, description: "color from parallel modes"),
            .text("These colors appear on the circle, the timeline blocks, chord detail panel, and suggestion cards, giving you a visual sense of harmonic movement as you build a progression."),
        ]
    }

    private var composeTabContent: [HelpParagraph] {
        [
            .text("The Compose tab is for manually building chord progressions. The left side shows the circle of fifths with controls for tension, octave, and borrowed chord presets. The right side (or below on iPhone) shows the chord detail panel for editing the selected block."),
            .text("Typical workflow:"),
            .bullet("Tap a chord on the circle to preview it, then tap its + button to add it to the timeline."),
            .bullet("Tap a block on the timeline to select it and open the detail editor."),
            .bullet("Use the detail panel to adjust pattern (block, arp up/down, strum), length (1-16 beats), extensions (7th, 9th, etc.), and octave."),
            .bullet("The mini keyboard at the bottom of the detail panel shows the exact voicing."),
        ]
    }

    private var suggestTabContent: [HelpParagraph] {
        [
            .text("The Suggest tab recommends what chord to play next. After you've added at least one chord to the timeline, the suggestion engine ranks candidates and displays them as cards."),
            .text("The engine scores each candidate chord using several factors:"),
            .bullet("Diatonic fit: Chords that belong to the current key score higher."),
            .bullet("Voice leading: Chords whose root is close in pitch to the previous chord's root score higher, because smooth voice leading sounds more natural."),
            .bullet("Tension boost: At higher tension settings, dominant-quality chords get a small score boost."),
            .text("Each suggestion card shows the chord symbol, confidence rank, and \"reason pills\" that explain why it was suggested (e.g. \"Smooth voice leading\", \"Circle-of-fifths motion\", \"Seventh color\"). Tap a card to add that chord to the timeline."),
        ]
    }

    private var timelineContent: [HelpParagraph] {
        [
            .text("The horizontal bar at the bottom of Compose and Suggest is the timeline -- a beat grid showing your chord progression left to right."),
            .bullet("Each block represents one chord with a length (1-16 beats), a playback pattern, and an octave setting."),
            .bullet("Tap a block to select it for editing in the detail panel."),
            .bullet("Long press a block for quick actions: preview, duplicate, or remove."),
            .bullet("Drag the handle on the left side of a block to reorder it."),
            .bullet("During playback, an orange cursor shows the current position."),
        ]
    }

    private var chordDetailContent: [HelpParagraph] {
        [
            .text("When you select a block on the timeline (Compose tab), the detail panel lets you fine-tune it:"),
            .bullet("Pattern: Block plays all notes simultaneously. Arp Up/Down plays notes one at a time ascending or descending. Strum plays a rapid cascade."),
            .bullet("Length: How many beats the chord occupies (1, 2, 4, 8, or 16)."),
            .bullet("Extensions: Triad is the base. Adding 7th, 9th, 11th, or 13th layers in extra notes for richer harmony. These are cumulative -- 9th includes 7th, 11th includes both, and so on."),
            .bullet("Octave: Shift the voicing up or down by octaves (-3 to +3)."),
            .bullet("Preview: Audition just this chord. Duplicate: Copy the block to the end. Remove: Delete it."),
        ]
    }

    private var borrowedChordsContent: [HelpParagraph] {
        [
            .text("Borrowed chords (modal interchange) are chords taken from a parallel scale or mode. For example, in C major, using an F minor chord borrows from C minor. They add color, surprise, and emotional depth."),
            .text("Use the borrowed preset picker to control how many borrowed chords appear on the circle:"),
            .bullet("Diatonic Only: No borrowed chords -- just the 7 from the current key."),
            .bullet("Conservative: 2 of the most common borrowed chords."),
            .bullet("Colorful: The full curated set for the current mode (3-4 chords)."),
            .bullet("Cinematic: Dramatic choices like bVI and bII."),
            .bullet("Jazz: Tritone substitutions and secondary dominants."),
            .bullet("Experimental: Unusual borrowings for adventurous writing."),
            .bullet("Everything: Every possible borrowed chord combined."),
            .text("Borrowed chords appear on the outermost ring of the circle with dashed pink/magenta borders, and are also included in the suggestion engine's candidate pool."),
        ]
    }

    private var tensionContent: [HelpParagraph] {
        [
            .text("The tension control determines how harmonically rich chords are. It affects both the global default for new chords and what extensions the suggestion engine applies."),
            .bullet("Triads: Simple three-note chords (root, third, fifth)."),
            .bullet("7ths: Adds a seventh for a jazzier sound."),
            .bullet("9ths: Adds seventh + ninth for lush harmony."),
            .bullet("11ths: Adds seventh + ninth + eleventh for dense voicings."),
            .bullet("13ths: Maximum richness -- all available extensions."),
            .text("You can also override extensions per block in the chord detail panel."),
        ]
    }

    private var playbackContent: [HelpParagraph] {
        [
            .text("Tap the play button to hear your progression. The app uses a built-in sampler with a piano sound and reverb. If the sampler is unavailable, a sine-wave synthesizer provides a fallback."),
            .text("For working with a DAW or external synth:"),
            .bullet("Go to the Files tab and enable Live MIDI to create a virtual CoreMIDI output port (\"ChordFlow Out\")."),
            .bullet("Select a MIDI channel (1-16) for the output."),
            .bullet("When Live MIDI is active, playback and previews send real MIDI note events instead of using the built-in sound."),
            .bullet("In your DAW, select \"ChordFlow Out\" as a MIDI input source on the track you want to receive the chords."),
        ]
    }

    private var filesContent: [HelpParagraph] {
        [
            .text("The Files tab handles saving, loading, and exporting:"),
            .bullet("Save: Stores the current progression as a .chordflow project file. The app also auto-saves when you make changes."),
            .bullet("Open: Browse and load previously saved projects."),
            .bullet("Import/Export: Use the system file picker to import .chordflow or .json files, or export to share with others."),
            .bullet("MIDI Export: Renders your progression as a Standard MIDI File (.mid) that can be opened in any DAW. The file uses the patterns, lengths, and extensions you've set on each block."),
            .bullet("Share: Send project or MIDI files via AirDrop, Messages, email, or any share extension."),
        ]
    }
}
#endif
