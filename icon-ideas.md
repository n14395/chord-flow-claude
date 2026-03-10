# ChordFlow App Icon Ideas

## Brand Context

- **App name**: ChordFlow
- **What it does**: Harmonic suggestion engine + MIDI sequencer. Users build chord progressions via a Circle of Fifths, get AI-ranked "next chord" suggestions, and export MIDI.
- **Color palette**: Deep indigo/navy background (#1A1B2E), warm amber/gold accent (#F5A623, "tonic"), blue (#4A90D9, "dominant"), green (#7ED321, "subdominant"), pink (#D94A8C, "borrowed").
- **Key visual elements in-app**: Circle of Fifths (concentric rings of note buttons), horizontal chord progression timeline (colored blocks), harmonic function color-coding.
- **Personality**: Professional music tool, dark/moody aesthetic, precise but creative.

---

## Concept 1: "Harmonic Ring"

**Core idea**: A stylized Circle of Fifths — the app's most distinctive and recognizable UI element — distilled into a bold icon-scale mark.

**Description**: A single circular ring of 12 evenly-spaced dots (or short arc segments) on a deep navy background, representing the 12 chromatic notes arranged in fifths order. Three or four adjacent dots are enlarged or filled with the tonic amber/gold color, representing the current key's diatonic cluster. One dot opposite or offset from the cluster glows in the dominant blue, suggesting harmonic tension and resolution. The remaining dots are dim, rendered in a muted version of the background (e.g., #3A3D5C border color). The circle sits centered in the icon with generous padding. No text, no extra ornamentation.

**Why it works**: Immediately communicates "music theory tool" to anyone who recognizes a Circle of Fifths. The selective color highlighting conveys the app's core value — it illuminates which chords matter in your key. Scales cleanly from 1024px down to 16px (the dots simplify into a ring at small sizes). The asymmetric coloring prevents it from looking like a generic loading spinner or clock.

**Rendering notes**: The dots should be slightly rounded squares or circles, ~15-20% of the ring radius in diameter. The gold cluster should have a subtle outer glow (same amber at 20-30% opacity) to create depth. Consider a very faint radial gradient from center (slightly lighter navy) outward to reinforce the concentric-ring motif from the in-app Circle of Fifths. The background should be the app's cfBackground (#1A1B2E), not pure black, so it has the branded indigo warmth.

---

## Concept 2: "Flowing Progression"

**Core idea**: A horizontal sequence of chord blocks — the progression timeline — flowing and curving upward in an arc, evoking both musical movement and the "Flow" in ChordFlow.

**Description**: Three to four rounded rectangles (the chord block shapes from the timeline view) arranged in a gentle ascending curve from bottom-left to upper-right. Each block is a different harmonic-function color: the first in amber/gold (tonic), the second in green (subdominant), the third in blue (dominant), and optionally a fourth in pink (borrowed). The blocks decrease slightly in opacity or size as they progress, giving a sense of motion and depth — as if they're flowing forward into the composition. A thin curved line or subtle trail connects the blocks, reinforcing the "flow" metaphor. The background is the deep navy.

**Why it works**: Directly represents what the user builds — a chord progression. The ascending arc suggests creative momentum and forward motion. The four harmonic-function colors are a distinctive signature of ChordFlow's UI that no other music app uses in quite this way. It reads clearly at small sizes because the shapes are simple geometric rectangles with strong color contrast. Even without musical knowledge, the icon communicates "sequence" and "creativity."

**Rendering notes**: The rounded rectangles should use the app's CFRadius.card (12pt corner radius, scaled proportionally). Each block should be roughly 20-25% of the icon width and about 40% of the icon height. The connecting trail should be very subtle — a 1-2pt line in cfBorder color or a gradient that fades between block colors. Blocks should overlap slightly (5-10%) in the horizontal axis to reinforce the sense of a flowing sequence. A slight drop shadow under each block (black at 20% opacity, 2-4pt offset) adds depth consistent with the app's elevated surface aesthetic.

---

## Concept 3: "Chord Bloom"

**Core idea**: An abstract radial burst where chord tones fan outward from a central point — a single moment of harmonic richness captured as a geometric bloom.

**Description**: From the center of the icon, four to five tapered "petals" or wedge shapes radiate outward at varied angles (not evenly spaced — grouped asymmetrically like the intervals in a chord voicing). Each petal is a different color from the harmonic palette: amber, blue, green, with one or two in lighter/mixed tones. The petals are widest at their tips and taper to a shared origin point, like a starburst or opening flower. The negative space between petals is the dark navy background. At the very center, a small bright circle (amber/gold) acts as the "root note" anchor. The overall silhouette is roughly circular but organic and asymmetric.

**Why it works**: Represents the harmonic concept at the heart of the app — a chord is multiple notes sounding simultaneously, each with its own character (interval, function). The radial form echoes the Circle of Fifths without literally copying it. The bloom/burst shape conveys the generative nature of the app (suggestions "blooming" from your current chord). It's abstract enough to be memorable and distinctive — it doesn't look like any existing music app icon. The asymmetry makes it feel musical rather than mechanical.

**Rendering notes**: The petals should have soft edges — rounded ends, possibly with a slight Gaussian blur at the tips to create a glow effect. Each petal should be 3-5pt wide at the base, expanding to 15-25pt at the tip (at 1024px scale). The angles between petals should roughly correspond to musical intervals (e.g., the gap between the root and third petal is wider than between the third and fifth, mirroring how chord tones are spaced). The center dot should be 8-10% of the icon size. Consider a very faint circular ring at ~60% radius in cfBorder color to subtly ground the composition and hint at the Circle of Fifths.
