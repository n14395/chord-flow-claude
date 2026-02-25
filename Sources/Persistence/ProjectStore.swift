import Foundation
import ChordFlowModels

public enum ProjectStoreError: Error {
    case unsupportedSchema(Int)
}

public struct ProjectStore: Sendable {
    public static let currentSchemaVersion = 1

    public init() {}

    public func encode(_ project: ProjectDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(project)
    }

    public func decode(_ data: Data) throws -> ProjectDocument {
        let decoder = JSONDecoder()
        let raw = try decoder.decode(ProjectDocument.self, from: data)
        return try migrate(raw)
    }

    public func migrate(_ input: ProjectDocument) throws -> ProjectDocument {
        switch input.schemaVersion {
        case ProjectStore.currentSchemaVersion:
            return input
        case 0:
            var migrated = input
            migrated.schemaVersion = ProjectStore.currentSchemaVersion
            if migrated.routingConfig.midiChannelMap.isEmpty {
                migrated.routingConfig.midiChannelMap = [0: 0]
            }
            return migrated
        default:
            throw ProjectStoreError.unsupportedSchema(input.schemaVersion)
        }
    }
}
