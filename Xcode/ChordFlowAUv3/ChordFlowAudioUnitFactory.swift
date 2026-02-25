import AudioToolbox
import Foundation

public final class ChordFlowAudioUnitFactory: NSObject, AUAudioUnitFactory {
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        try ChordFlowMIDIProcessorAudioUnit(componentDescription: componentDescription, options: [])
    }

    // Required by NSExtensionRequestHandling via AUAudioUnitFactory protocol inheritance.
    public func beginRequest(with context: NSExtensionContext) {
        context.completeRequest(returningItems: nil)
    }
}
