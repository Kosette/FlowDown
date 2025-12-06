//
//  ModelManager+Inference.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/29/25.
//

import ChatClientKit
import Foundation
import FoundationModels
import GPTEncoder
import MLX
import Storage
import UIKit

extension ModelManager {
    // - imageProcessingFailure : "height: 1 must be larger than factor: 28"
    static let testImage: UIImage = .init(
        color: .accent,
        size: .init(width: 64, height: 64),
    )

    private static let testImageDataURL: URL? = {
        guard let data = testImage.pngData() else { return nil }
        let base64 = data.base64EncodedString()
        return URL(string: "data:image/png;base64,\(base64)")
    }()

    func testLocalModel(_ model: LocalModel, completion: @escaping (Result<Void, Error>) -> Void) {
        guard MLX.GPU.isSupported else {
            completion(.failure(NSError(domain: "GPU", code: -1, userInfo: [
                NSLocalizedDescriptionKey: String(localized: "Your device does not support MLX."),
            ])))
            return
        }
        Task.detached {
            assert(!Thread.isMainThread)

            do {
                let preferredKind: MLXModelKind = model.capabilities.contains(.visual) ? .vlm : .llm
                let client = MLXChatClient(
                    url: ModelManager.shared.modelContent(for: model),
                    preferredKind: preferredKind,
                )
                await client.errorCollector.clear()

                let userContent: ChatRequestBody.Message.MessageContent<String, [ChatRequestBody.Message.ContentPart]> = {
                    guard model.capabilities.contains(.visual),
                          let imageURL = Self.testImageDataURL
                    else {
                        return .text("YES or NO")
                    }
                    return .parts([
                        .text("YES or NO"),
                        .imageURL(imageURL, detail: .low),
                    ])
                }()

                let stream = try await client.streamingChat(
                    body: .init(
                        messages: [
                            .system(content: .text("Reply YES to every query.")),
                            .user(content: userContent),
                        ],
                        maxCompletionTokens: 32,
                        temperature: 0,
                    ),
                )

                var reasoningContent = ""
                var responseContent = ""
                var collectedToolCalls: [ToolRequest] = []

                for try await object in stream {
                    switch object {
                    case let .reasoning(value):
                        reasoningContent += value
                    case let .text(value):
                        responseContent += value
                    case let .tool(call):
                        collectedToolCalls.append(call)
                    case let .image(url):
                        // MARK: TODO

                        print(url)
                    }
                }

                var trimmedContent = responseContent
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                for terminator in ChatClientConstants.additionalTerminatingTokens {
                    while trimmedContent.hasSuffix(terminator) {
                        trimmedContent.removeLast(terminator.count)
                    }
                }

                trimmedContent = trimmedContent.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmedContent.isEmpty,
                   reasoningContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   collectedToolCalls.isEmpty
                {
                    if let error = client.collectedErrors, !error.isEmpty {
                        throw NSError(
                            domain: "Model",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: error],
                        )
                    }

                    completion(
                        .failure(
                            NSError(
                                domain: "Model",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: String(localized: "Failed to generate text.")],
                            ),
                        ),
                    )
                } else {
                    Logger.model.debugFile("model \(model.model_identifier) generates output for test case: \(trimmedContent)")
                    completion(.success(()))
                }
            } catch {
                Logger.model.errorFile("local model test failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    func testCloudModel(_ model: CloudModel, completion: @escaping (Result<Void, Error>) -> Void) {
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let inference = try await infer(
                    with: model.id,
                    maxCompletionTokens: 512,
                    input: [
                        .system(content: .text("Reply YES to every query.")),
                        .user(content: .text("YES or NO")),
                    ],
                )
                if !isEmptyResponse(inference) {
                    completion(.success(()))
                } else {
                    completion(
                        .failure(
                            NSError(
                                domain: "Model",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: String(localized: "Model did not produce any textual output.")],
                            ),
                        ),
                    )
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    func testAppleIntelligenceModel(completion: @escaping (Result<Void, Error>) -> Void) {
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            guard AppleIntelligenceModel.shared.isAvailable else {
                completion(.failure(NSError(domain: "AppleIntelligence", code: -1, userInfo: [NSLocalizedDescriptionKey: String(localized: "Apple Intelligence is not available: \(AppleIntelligenceModel.shared.availabilityStatus)")])))
                return
            }
            Task {
                do {
                    let client = AppleIntelligenceChatClient()
                    let body = ChatRequestBody(
                        messages: [
                            .system(content: .text("Reply YES to every query.")),
                            .user(content: .text("YES or NO")),
                        ],
                        temperature: 0,
                    )
                    let response = try await client.chat(body: body)
                    if !isEmptyResponse(response) {
                        completion(.success(()))
                    } else {
                        completion(.failure(NSError(
                            domain: "AppleIntelligence",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No response from Apple Intelligence."],
                        )))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        } else {
            completion(.failure(NSError(domain: "AppleIntelligence", code: -1, userInfo: [NSLocalizedDescriptionKey: "Requires iOS 26+"])))
        }
    }
}

extension ModelManager {
    /// Get the body fields configured for a cloud model
    /// - Parameter identifier: The model identifier
    /// - Returns: A dictionary of body fields, or empty dictionary if not found or empty
    public func modelBodyFields(for identifier: ModelIdentifier) -> [String: Any] {
        guard let model = cloudModel(identifier: identifier),
              !model.body_fields.isEmpty,
              let data = model.body_fields.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return jsonObject
    }

    private static func hasNonEmptyText(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isEmptyResponse(_ response: ChatResponse) -> Bool {
        !Self.hasNonEmptyText(response.text)
            && !Self.hasNonEmptyText(response.reasoning)
            && response.tools.isEmpty
            && response.images.isEmpty
    }

    private func chatService(
        for identifier: ModelIdentifier,
        additionalBodyField: [String: Any],
    ) throws -> any ChatService {
        if #available(iOS 26.0, macCatalyst 26.0, *), identifier == AppleIntelligenceModel.shared.modelIdentifier {
            return AppleIntelligenceChatClient()
        }
        if let model = cloudModel(identifier: identifier) {
            let endpoint = resolveEndpointComponents(from: model.endpoint)
            // Use additionalBodyField directly without merging model's body_fields
            // Callers should explicitly merge body_fields if needed
            switch model.response_format {
            case .chatCompletions:
                return RemoteCompletionsChatClient(
                    model: model.model_identifier,
                    baseURL: endpoint.baseURL,
                    path: endpoint.path,
                    apiKey: model.token,
                    additionalHeaders: model.headers,
                    additionalBodyField: additionalBodyField,
                )
            case .responses:
                return RemoteResponsesChatClient(
                    model: model.model_identifier,
                    baseURL: endpoint.baseURL,
                    path: endpoint.path,
                    apiKey: model.token,
                    additionalHeaders: model.headers,
                    additionalBodyField: additionalBodyField,
                )
            }
        } else if let model = localModel(identifier: identifier) {
            let preferredKind: MLXModelKind = model.capabilities.contains(.visual) ? .vlm : .llm
            return MLXChatClient(
                url: modelContent(for: model),
                preferredKind: preferredKind,
            )
        } else {
            throw NSError(
                domain: "Model",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "Model not found.")],
            )
        }
    }

    private func resolveEndpointComponents(from endpoint: String) -> (baseURL: String?, path: String?) {
        guard !endpoint.isEmpty,
              let components = URLComponents(string: endpoint),
              components.host != nil
        else {
            return (endpoint.isEmpty ? nil : endpoint, endpoint.isEmpty ? nil : "/")
        }

        var baseComponents = URLComponents()
        baseComponents.scheme = components.scheme
        baseComponents.user = components.user
        baseComponents.password = components.password
        baseComponents.host = components.host
        baseComponents.port = components.port
        let baseURL = baseComponents.string

        var pathComponents = URLComponents()
        let pathValue = components.path.isEmpty ? "/" : components.path
        pathComponents.path = pathValue
        pathComponents.queryItems = components.queryItems
        pathComponents.fragment = components.fragment
        let normalizedPath = pathComponents.string ?? pathValue

        return (baseURL, normalizedPath)
    }

    func prepareRequestBody(
        modelID: ModelIdentifier,
        messages: [ChatRequestBody.Message],
    ) throws -> [ChatRequestBody.Message] {
        var messages = messages
        if let model = cloudModel(identifier: modelID) {
            // this model requires developer mode to work
            if model.capabilities.contains(.developerRole) {
                messages = messages.map { message in
                    switch message {
                    case let .system(content, name):
                        .developer(content: content, name: name)
                    default:
                        message
                    }
                }
            }
        }
        return messages
    }

    func infer(
        with modelID: ModelIdentifier,
        maxCompletionTokens: Int? = nil,
        input: [ChatRequestBody.Message],
        tools: [ChatRequestBody.Tool]? = nil,
    ) async throws -> ChatResponse {
        let client = try chatService(
            for: modelID,
            additionalBodyField: modelBodyFields(for: modelID),
        )
        let body = try ChatRequestBody(
            messages: prepareRequestBody(modelID: modelID, messages: input),
            maxCompletionTokens: maxCompletionTokens,
            temperature: .init(temperature),
            tools: tools,
        )
        return try await client.chat(body: body)
    }

    func streamingInfer(
        with modelID: ModelIdentifier,
        maxCompletionTokens: Int? = nil,
        input: [ChatRequestBody.Message],
        tools: [ChatRequestBody.Tool]? = nil,
    ) async throws -> AnyAsyncSequence<ChatResponseChunk> {
        let client = try chatService(
            for: modelID,
            additionalBodyField: modelBodyFields(for: modelID),
        )
        let body = try ChatRequestBody(
            messages: prepareRequestBody(modelID: modelID, messages: input),
            maxCompletionTokens: maxCompletionTokens,
            temperature: .init(temperature),
            tools: tools,
        )
        return try await client.streamingChat(body: body)
    }

    func calculateEstimateTokensUsingCommonEncoder(
        input: [ChatRequestBody.Message],
        tools: [ChatRequestBody.Tool],
    ) -> Int {
        assert(!Thread.isMainThread)

        func text(
            _ content: ChatRequestBody.Message.MessageContent<String, [String]>,
        ) -> String {
            switch content {
            case let .text(text):
                text
            case let .parts(strings):
                strings.joined(separator: "\n")
            }
        }

        // will pass to encoder later
        var estimatedInferenceText = ""

        // when processing images, assume 1 image = 512 tokens
        var estimatedAdditionalTokens = 0

        for message in input {
            switch message {
            case let .assistant(content, toolCalls, reasoning):
                estimatedInferenceText += "role: assistant\n"
                if let content { estimatedInferenceText += text(content) }
                if let reasoning, !reasoning.isEmpty {
                    estimatedInferenceText += "reasoning: \(reasoning)\n"
                }
                if let toolCalls, !toolCalls.isEmpty {
                    estimatedInferenceText += "calls: \(toolCalls)\n"
                }
            case let .system(content, name):
                estimatedInferenceText += "role: assistant\n"
                estimatedInferenceText += text(content)
                if let name { estimatedInferenceText += "name: \(name)\n" }
            case let .user(content, name):
                estimatedInferenceText += "role: user\n"
                if let name { estimatedInferenceText += "name: \(name)\n" }
                switch content {
                case let .text(text):
                    estimatedInferenceText += text
                case let .parts(contentParts):
                    for part in contentParts {
                        switch part {
                        case let .text(text): estimatedInferenceText += text
                        case .imageURL: estimatedAdditionalTokens += 512
                        case .audioBase64: estimatedAdditionalTokens += 1024
                        }
                    }
                }
            case let .developer(content, name):
                estimatedInferenceText += "role: developer\n"
                estimatedInferenceText += text(content)
                if let name { estimatedInferenceText += "name: \(name)\n" }
            case let .tool(content, id):
                estimatedInferenceText += "role: tool \(id)\n"
                estimatedInferenceText += text(content)
            }
        }

        if !tools.isEmpty {
            let encoder = JSONEncoder()
            if let toolText = try? encoder.encode(tools),
               let toolString = String(data: toolText, encoding: .utf8)
            {
                estimatedInferenceText += "tools: \(toolString)\n"
            } else { assertionFailure() }
        }

        let encoder = GPTEncoder()
        let tokens = encoder.encode(text: estimatedInferenceText)

        return tokens.count + estimatedAdditionalTokens
    }
}
