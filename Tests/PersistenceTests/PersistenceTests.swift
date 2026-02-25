import Foundation
import Testing
import Persistence
import ChordFlowModels

struct PersistenceTests {
    @Test
    func encodeDecodeRoundTrip() throws {
        let project = ProjectDocument(
            schemaVersion: 1,
            tempo: 122,
            keyContext: KeyContext(tonic: .d, mode: .minor),
            blocks: [
                SequenceBlock(barStart: 0, beatStart: 0, lengthBeats: 4, chordToken: ChordToken(root: .d, quality: .minor))
            ]
        )

        let store = ProjectStore()
        let data = try store.encode(project)
        let decoded = try store.decode(data)

        #expect(decoded == project)
    }

    @Test
    func schemaMigrationFromZero() throws {
        let legacy = ProjectDocument(
            schemaVersion: 0,
            tempo: 110,
            keyContext: KeyContext(tonic: .c, mode: .major),
            blocks: [],
            routingConfig: RoutingConfig(outputMode: .virtualMIDI, midiChannelMap: [:], clockMode: .internalTransport)
        )

        let store = ProjectStore()
        let migrated = try store.migrate(legacy)

        #expect(migrated.schemaVersion == ProjectStore.currentSchemaVersion)
        #expect(!migrated.routingConfig.midiChannelMap.isEmpty)
    }
}
