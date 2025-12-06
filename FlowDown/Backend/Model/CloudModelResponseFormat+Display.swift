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
            String(localized: "Chat Completions")
        case .responses:
            String(localized: "Responses")
        }
    }

    var localizedDescription: String {
        switch self {
        case .chatCompletions:
            String(localized: "Use OpenAI-compatible chat completions (POST /v1/chat/completions).")
        case .responses:
            String(localized: "Use the newer responses API (POST /v1/responses) for streaming and structured outputs.")
        }
    }

    var symbolName: String {
        switch self {
        case .chatCompletions:
            "text.quote"
        case .responses:
            "arrow.triangle.2.circlepath"
        }
    }
}

