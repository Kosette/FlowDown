//
//  MCPTool.swift
//  FlowDown
//
//  Created by 秋星桥 on 7/10/25.
//

import AlertController
import ChatClientKit
import ConfigurableKit
import Foundation
import MCP
import Storage
import XMLCoder

class MCPTool: ModelTool, @unchecked Sendable {
    // MARK: - Properties

    let toolInfo: MCPToolInfo
    let mcpService: MCPService

    // MARK: - Initialization

    init(toolInfo: MCPToolInfo, mcpService: MCPService) {
        self.toolInfo = toolInfo
        self.mcpService = mcpService
        super.init()
    }

    // MARK: - ModelTool Implementation

    override var shortDescription: String {
        toolInfo.description ?? String(localized: "MCP Tool")
    }

    override var interfaceName: String {
        toolInfo.name
    }

    override var functionName: String {
        toolInfo.name
    }

    override var definition: ChatRequestBody.Tool {
        let parameters = convertMCPSchemaToJSONValues(toolInfo.inputSchema)
        return .function(
            name: toolInfo.name,
            description: toolInfo.description ?? String(localized: "MCP Tool"),
            parameters: parameters,
            strict: true
        )
    }

    override var isEnabled: Bool {
        get { true }
        set { assertionFailure() }
    }

    override class var controlObject: ConfigurableObject {
        assertionFailure()
        return .init(
            icon: "hammer",
            title: "MCP Tool",
            explain: "Tools from connected MCP servers",
            key: "MCP.Tools.Enabled",
            defaultValue: true,
            annotation: .boolean
        )
    }

    // MARK: - Tool Execution

    override func execute(with input: String, anchorTo _: UIView) async throws -> String {
        do {
            var arguments: [String: Value]?
            if !input.isEmpty {
                let data = Data(input.utf8)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    arguments = json.compactMapValues { value in
                        convertJSONValueToMCPValue(value)
                    }
                }
            }

            let result = try await mcpService.callTool(
                name: toolInfo.name,
                arguments: arguments,
                from: toolInfo.serverID
            )

            // isError is optional
            if result.isError == true {
                Logger.network.errorFile("MCP Tool \(toolInfo.name) returned error: \(result.content)")
                let text = "MCP Tool returned error: \(result.content.debugDescription)"
                throw NSError(
                    domain: "MCPToolErrorDomain",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: text]
                )
            }

            // later on we process the result content and map audio and image to user attachment
            // so it can be seen by model
            return result.0.serializedRawContent()
        } catch {
            throw error
        }
    }
}

extension [Tool.Content] {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()

    func serializedRawContent() -> String {
        do {
            let data = try Self.encoder.encode(self)
            let text = String(data: data, encoding: .utf8)
            return text ?? ""
        } catch {
            Logger.chatService.errorFile("failed to encode tool content: \(error.localizedDescription)")
            return error.localizedDescription
        }
    }

    static func decodeContents(_ input: String?) throws -> [Tool.Content] {
        guard let input else { return [] }
        let data = Data(input.utf8)
        return try decoder.decode([Tool.Content].self, from: data)
    }
}

extension MCPTool {
    private func convertMCPSchemaToJSONValues(_ mcpSchema: Value?) -> [String: AnyCodingValue] {
        guard let mcpSchema else {
            return ["type": .string("object"), "properties": .object([:]), "additionalProperties": .bool(false)]
        }

        if case let .object(dict) = convertMCPValueToJSONValue(mcpSchema) {
            // Preserve original values if present, otherwise set default values
            var result = dict
            if result["properties"] == nil {
                result["properties"] = .object([:])
            }
            if let additionalProps = result["additionalProperties"] {
                // Convert empty object {} to false
                if case let .object(obj) = additionalProps, obj.isEmpty {
                    result["additionalProperties"] = .bool(false)
                }
            } else {
                result["additionalProperties"] = .bool(false)
            }
            return result
        }
        return ["type": .string("object"), "properties": .object([:]), "additionalProperties": .bool(false)]
    }

    private func convertMCPValueToJSONValue(_ value: Value) -> AnyCodingValue {
        switch value {
        case let .string(string):
            .string(string)
        case let .int(int):
            .int(int)
        case let .double(double):
            .double(double)
        case let .bool(bool):
            .bool(bool)
        case let .array(values):
            .array(values.map { convertMCPValueToJSONValue($0) })
        case let .object(dict):
            .object(dict.mapValues { convertMCPValueToJSONValue($0) })
        case .null:
            .null(NSNull())
        case let .data(mimeType: mimeType, _):
            .string("[Data: \(mimeType ?? "unknown")]")
        }
    }

    func convertJSONValueToMCPValue(_ jsonValue: Any) -> Value? {
        switch jsonValue {
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if number.isBool {
                return .bool(number.boolValue)
            } else if number.isInteger {
                return .int(number.intValue)
            } else {
                return .double(number.doubleValue)
            }
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let array as [Any]:
            let values = array.compactMap { convertJSONValueToMCPValue($0) }
            return .array(values)
        case let dict as [String: Any]:
            let pairs = dict.compactMapValues { convertJSONValueToMCPValue($0) }
            return .object(pairs)
        case is NSNull:
            return .null
        default:
            return nil
        }
    }
}
