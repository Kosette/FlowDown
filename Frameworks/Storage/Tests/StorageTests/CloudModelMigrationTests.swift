//
//  CloudModelMigrationTests.swift
//  StorageTests
//
//  Created by GPT-5 Codex on 2025/12/06.
//

@testable import Storage
import Foundation
import Testing
import WCDBSwift

@Suite("CloudModel migrations")
struct CloudModelMigrationTests {
    @Test("Renames bodyFields column and preserves values")
    func migrateBodyFieldsColumn() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let databaseURL = tempDirectory.appendingPathComponent("CloudModel.db")
        let database = Database(at: databaseURL.path)
        defer { database.close() }

        // Create legacy schema with camelCase column
        try database.create(table: CloudModel.tableName, of: LegacyCloudModel.self)

        var legacy = LegacyCloudModel(deviceId: Storage.deviceId)
        legacy.objectId = "legacy-\(UUID().uuidString)"
        legacy.model_identifier = "gpt-legacy"
        legacy.endpoint = "https://example.com/v1/chat/completions"
        legacy.headers = ["X-Test": "1"]
        legacy.bodyFields = #"{"mode":"legacy"}"#
        try database.insertOrReplace([legacy], intoTable: CloudModel.tableName)

        // Perform migration under test
        let migration = MigrationV4ToV5()
        try migration.migrate(db: database)

        let models: [CloudModel] = try database.getObjects(fromTable: CloudModel.tableName)
        let migrated = try #require(models.first)
        #expect(migrated.objectId == legacy.objectId)
        #expect(migrated.body_fields == legacy.bodyFields)
        #expect(migrated.response_format == .default)

        let columns = try fetchColumnNames(in: CloudModel.tableName, database: database)
        #expect(columns.contains("body_fields"))
        #expect(!columns.contains("bodyFields"))
        #expect(columns.contains("response_format"))
    }
}

private func fetchColumnNames(in table: String, database: Database) throws -> [String] {
    let pragma = StatementPragma().pragma(.tableInfo, ofTable: table)
    let rows = try database.getRows(from: pragma)
    return rows.map { $0[1].stringValue }
}

private struct LegacyCloudModel: TableNamed, TableCodable {
    static let tableName: String = CloudModel.tableName

    var objectId: String = UUID().uuidString
    var deviceId: String
    var model_identifier: String = ""
    var model_list_endpoint: String = ""
    var creation: Date = .now
    var modified: Date = .now
    var removed: Bool = false
    var endpoint: String = ""
    var token: String = ""
    var headers: [String: String] = [:]
    var bodyFields: String = ""
    var capabilities: Set<ModelCapabilities> = []
    var context: ModelContextLength = .short_8k
    var temperature_preference: ModelTemperaturePreference = .inherit
    var comment: String = ""
    var name: String = ""

    init(deviceId: String) {
        self.deviceId = deviceId
    }

    enum CodingKeys: String, CodingTableKey {
        typealias Root = LegacyCloudModel

        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(objectId, isPrimary: true, isNotNull: true, isUnique: true)
            BindColumnConstraint(deviceId, isNotNull: true)
            BindColumnConstraint(model_identifier, isNotNull: true, defaultTo: "")
            BindColumnConstraint(model_list_endpoint, isNotNull: true, defaultTo: "")
            BindColumnConstraint(creation, isNotNull: true)
            BindColumnConstraint(modified, isNotNull: true)
            BindColumnConstraint(removed, isNotNull: false, defaultTo: false)
            BindColumnConstraint(endpoint, isNotNull: true, defaultTo: "")
            BindColumnConstraint(token, isNotNull: true, defaultTo: "")
            BindColumnConstraint(headers, isNotNull: true, defaultTo: [String: String]())
            BindColumnConstraint(bodyFields, isNotNull: true, defaultTo: "")
            BindColumnConstraint(capabilities, isNotNull: true, defaultTo: Set<ModelCapabilities>())
            BindColumnConstraint(context, isNotNull: true, defaultTo: ModelContextLength.short_8k)
            BindColumnConstraint(comment, isNotNull: true, defaultTo: "")
            BindColumnConstraint(name, isNotNull: true, defaultTo: "")
            BindColumnConstraint(temperature_preference, isNotNull: true, defaultTo: ModelTemperaturePreference.inherit)
        }

        case objectId
        case deviceId
        case model_identifier
        case model_list_endpoint
        case creation
        case modified
        case removed
        case endpoint
        case token
        case headers
        case bodyFields
        case capabilities
        case context
        case comment
        case name
        case temperature_preference
    }
}


