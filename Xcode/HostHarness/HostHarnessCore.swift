import Foundation
import AVFoundation
import AudioToolbox

public enum HostHarnessCore {
    public static let componentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_MIDIProcessor,
        componentSubType: fourCC("chrd"),
        componentManufacturer: fourCC("NWF1"),
        componentFlags: 0,
        componentFlagsMask: 0
    )

    public static func run() {
        let manager = AVAudioUnitComponentManager.shared()
        let components = manager.components(matching: NSPredicate(format: "typeName CONTAINS[c] %@", "MIDI"))

        print("[Harness] Found \(components.count) MIDI-capable components")
        if let match = components.first(where: { $0.audioComponentDescription.componentSubType == componentDescription.componentSubType }) {
            print("[Harness] Found ChordFlow AU component: \(match.name)")
        } else {
            print("[Harness] ChordFlow AU component not discovered. Install/run ChordFlowApp on simulator/device first.")
        }

        print("[Harness] Logic workflow: instantiate MIDI FX on software instrument track, start transport, automate Tension/Swing.")
        print("[Harness] AUM workflow: load MIDI processor slot, route to synth app, verify beat-sync chord output.")
    }

    public static func fourCC(_ s: String) -> OSType {
        s.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}
