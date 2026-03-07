import SwiftUI
import UIKit
import AudioToolbox

// MARK: - ViewModel

final class AUv3ViewModel: ObservableObject {
    private let audioUnit: ChordFlowMIDIProcessorAudioUnit
    private var parameterObservation: AUParameterObserverToken?

    @Published var tonic: Float = 0
    @Published var mode: Float = 0
    @Published var tension: Float = 0.35
    @Published var pattern: Float = 0
    @Published var swing: Float = 0.1
    @Published var humanize: Float = 0.1

    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private let modeNames = ["Major", "Minor", "Ionian", "Dorian", "Phrygian", "Lydian",
                             "Mixolydian", "Aeolian", "Locrian", "Melodic Minor",
                             "Harmonic Minor", "Harmonic Major", "Double Harmonic",
                             "Phrygian Dominant", "Lydian Dominant", "Lydian Augmented",
                             "Locrian #2", "Super Locrian", "Neapolitan Minor",
                             "Neapolitan Major", "Hungarian Minor", "Romanian Minor",
                             "Persian", "Enigmatic"]
    private let patternNames = ["Block", "Arp Up", "Arp Down", "Strum"]

    init(audioUnit: ChordFlowMIDIProcessorAudioUnit) {
        self.audioUnit = audioUnit
        readAll()

        parameterObservation = audioUnit.parameterTree?.token(byAddingParameterObserver: { [weak self] address, value in
            DispatchQueue.main.async {
                self?.handleExternal(address: address, value: value)
            }
        })
    }

    deinit {
        if let token = parameterObservation {
            audioUnit.parameterTree?.removeParameterObserver(token)
        }
    }

    var tonicName: String { noteNames[Int(tonic.rounded()) % noteNames.count] }
    var modeName: String {
        let idx = Int(mode.rounded())
        return idx < modeNames.count ? modeNames[idx] : "?"
    }
    var patternName: String {
        let idx = Int(pattern.rounded())
        return idx < patternNames.count ? patternNames[idx] : "?"
    }
    var modeCount: Float { Float(modeNames.count - 1) }

    // MARK: - Read from AU

    private func readAll() {
        tonic = audioUnit.tonicParameter.value
        mode = audioUnit.modeParameter.value
        tension = audioUnit.tensionParameter.value
        pattern = audioUnit.patternParameter.value
        swing = audioUnit.swingParameter.value
        humanize = audioUnit.humanizeParameter.value
    }

    private func handleExternal(address: AUParameterAddress, value: AUValue) {
        switch address {
        case 0: tonic = value
        case 1: mode = value
        case 2: tension = value
        case 3: pattern = value
        case 4: swing = value
        case 5: humanize = value
        default: break
        }
    }

    // MARK: - Write to AU

    func setTonic(_ value: Float) {
        tonic = value
        audioUnit.tonicParameter.value = value
    }

    func setMode(_ value: Float) {
        mode = value
        audioUnit.modeParameter.value = value
    }

    func setTension(_ value: Float) {
        tension = value
        audioUnit.tensionParameter.value = value
    }

    func setPattern(_ value: Float) {
        pattern = value
        audioUnit.patternParameter.value = value
    }

    func setSwing(_ value: Float) {
        swing = value
        audioUnit.swingParameter.value = value
    }

    func setHumanize(_ value: Float) {
        humanize = value
        audioUnit.humanizeParameter.value = value
    }
}

// MARK: - SwiftUI View

struct AUv3View: View {
    @ObservedObject var vm: AUv3ViewModel

    // Match the app's dark theme
    private let bgColor = Color(red: 0x0E / 255, green: 0x0F / 255, blue: 0x1D / 255)
    private let surfaceColor = Color(red: 0x25 / 255, green: 0x27 / 255, blue: 0x40 / 255)
    private let borderColor = Color(red: 0x3A / 255, green: 0x3D / 255, blue: 0x5C / 255)
    private let textPrimary = Color(red: 0xF0 / 255, green: 0xF0 / 255, blue: 0xF5 / 255)
    private let textSecondary = Color(red: 0x8B / 255, green: 0x8D / 255, blue: 0xA3 / 255)
    private let accentTonic = Color(red: 0xF5 / 255, green: 0xA6 / 255, blue: 0x23 / 255)
    private let accentDominant = Color(red: 0x4A / 255, green: 0x90 / 255, blue: 0xD9 / 255)
    private let accentSubdominant = Color(red: 0x7E / 255, green: 0xD3 / 255, blue: 0x21 / 255)

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("ChordFlow")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                Spacer()
                Text("MIDI FX")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(accentDominant)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentDominant.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 4)

            // Key selection
            VStack(spacing: 8) {
                paramLabel("Key")
                HStack(spacing: 12) {
                    // Tonic picker
                    paramPicker(value: $vm.tonic, range: 0...11, label: vm.tonicName, color: accentTonic) {
                        vm.setTonic($0)
                    }
                    // Mode picker
                    paramPicker(value: $vm.mode, range: 0...vm.modeCount, label: vm.modeName, color: accentTonic) {
                        vm.setMode($0)
                    }
                }
            }
            .padding(12)
            .background(surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Tension slider
            paramCard("Tension", value: $vm.tension, range: 0...1, color: accentDominant,
                      displayValue: "\(Int(vm.tension * 100))%") {
                vm.setTension($0)
            }

            // Pattern picker
            VStack(spacing: 8) {
                paramLabel("Pattern")
                paramPicker(value: $vm.pattern, range: 0...3, label: vm.patternName, color: accentSubdominant) {
                    vm.setPattern($0)
                }
            }
            .padding(12)
            .background(surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Swing & Humanize
            HStack(spacing: 12) {
                paramCard("Swing", value: $vm.swing, range: 0...0.8, color: textSecondary,
                          displayValue: "\(Int(vm.swing / 0.8 * 100))%") {
                    vm.setSwing($0)
                }
                paramCard("Humanize", value: $vm.humanize, range: 0...1, color: textSecondary,
                          displayValue: "\(Int(vm.humanize * 100))%") {
                    vm.setHumanize($0)
                }
            }
        }
        .padding(16)
        .background(bgColor)
    }

    // MARK: - Components

    private func paramLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
            Spacer()
        }
    }

    private func paramCard(_ title: String, value: Binding<Float>, range: ClosedRange<Float>,
                           color: Color, displayValue: String, onChanged: @escaping (Float) -> Void) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary)
                Spacer()
                Text(displayValue)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(textPrimary)
            }
            Slider(value: value, in: range) { _ in
                onChanged(value.wrappedValue)
            }
            .tint(color)
        }
        .padding(12)
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func paramPicker(value: Binding<Float>, range: ClosedRange<Float>,
                             label: String, color: Color, onChanged: @escaping (Float) -> Void) -> some View {
        HStack(spacing: 8) {
            Button {
                let newVal = max(range.lowerBound, value.wrappedValue - 1)
                onChanged(newVal)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(borderColor.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                let newVal = min(range.upperBound, value.wrappedValue + 1)
                onChanged(newVal)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}


