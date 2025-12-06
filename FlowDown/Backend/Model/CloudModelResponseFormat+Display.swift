//
//  CloudModelResponseFormat+Display.swift
//  FlowDown
//
//  Created by GPT-5 Codex on 2025/12/06.
//

import Foundation
import Storage

extension CloudModelResponseFormat {
    var localizedTitle: String {
        switch self {
        case .chatCompletions:
            String(localized: "Chat Completions Format")
        case .responses:
            String(localized: "Responses Format")
        }
    }

    var localizedDescription: String {
        switch self {
        case .chatCompletions:
            String(localized: "Use OpenAI-compatible chat completions.") + " " + "(POST /v1/chat/completions)"
        case .responses:
            String(localized: "Use OpenAI-compatible chat response format.") + " " + "(POST /v1/responses)"
        }
    }

    var symbolName: String {
        switch self {
        case .chatCompletions:
            "1.circle"
        case .responses:
            "2.circle"
        }
    }
}

extension CloudModelResponseFormat {
    static func inferredFormat(fromEndpoint endpoint: String) -> CloudModelResponseFormat? {
        guard let normalized = normalizeEndpoint(endpoint) else { return nil }
        return allCases.first { $0.matchesNormalizedEndpoint(normalized) }
    }
}

// MARK: - Helpers

private extension CloudModelResponseFormat {
    static func normalizeEndpoint(_ endpoint: String) -> String? {
        var normalized = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        normalized = normalized.lowercased()
        if let fragmentIndex = normalized.firstIndex(of: "#") {
            normalized = String(normalized[..<fragmentIndex])
        }
        if let queryIndex = normalized.firstIndex(of: "?") {
            normalized = String(normalized[..<queryIndex])
        }
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.last == "/" {
            normalized.removeLast()
        }
        return normalized.isEmpty ? nil : normalized
    }

    func matchesNormalizedEndpoint(_ endpoint: String) -> Bool {
        endpointSuffixes.contains { endpoint.hasSuffix($0) }
    }

    var endpointSuffixes: [String] {
        switch self {
        case .chatCompletions:
            ["/v1/chat/completions", "/chat/completions"]
        case .responses:
            ["/v1/responses", "/responses"]
        }
    }
}
