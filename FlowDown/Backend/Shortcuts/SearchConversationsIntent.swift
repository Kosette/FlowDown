import AppIntents
import Foundation
import Storage

struct SearchConversationsIntent: AppIntent {
    static var title: LocalizedStringResource {
        LocalizedStringResource("Search Conversations")
    }

    static var description = IntentDescription(
        LocalizedStringResource(
            "Search saved conversations by keyword, date, and whether they include images."
        )
    )

    @Parameter(
        title: LocalizedStringResource("Keyword"),
        default: nil
    )
    var keyword: String?

    @Parameter(
        title: LocalizedStringResource("Include Images")
    )
    var includeImages: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Search conversations") {
            \.$keyword
            \.$includeImages
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> & ProvidesDialog {
        let sanitizedKeyword = keyword?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        let results = SearchConversationsIntentHelper.search(
            keyword: sanitizedKeyword,
            requireImages: includeImages
        )

        if results.isEmpty {
            let fallback = String(localized: "No conversations found.")
            let dialog = IntentDialog(.init(stringLiteral: fallback))
            return .result(value: [fallback], dialog: dialog)
        }

        let summaryFormat = String(
            localized: "%d conversation(s) matched your criteria."
        )
        let dialogMessage = String(format: summaryFormat, results.count)
        let dialog = IntentDialog(.init(stringLiteral: dialogMessage))
        return .result(value: results, dialog: dialog)
    }
}

enum SearchConversationsIntentHelper {
    static func search(
        keyword: String?,
        requireImages: Bool
    ) -> [String] {
        let conversations = sdb.conversationList()
        guard !conversations.isEmpty else { return [] }

        var results: [String] = []
        let headerFormatter = DateFormatter()
        headerFormatter.dateStyle = .medium
        headerFormatter.timeStyle = .short

        let messageFormatter = DateFormatter()
        messageFormatter.dateStyle = .short
        messageFormatter.timeStyle = .short

        for conversation in conversations {
            let messages = sdb
                .listMessages(within: conversation.id)
                .filter { [.user, .assistant].contains($0.role) }

            if messages.isEmpty {
                continue
            }

            if requireImages, !conversationHasImage(messages: messages) {
                continue
            }

            let filteredMessages: [Message]
            if let keyword, !keyword.isEmpty {
                filteredMessages = messages.filter { message in
                    message.matches(keyword: keyword)
                }
                if filteredMessages.isEmpty {
                    continue
                }
            } else {
                filteredMessages = messages
            }

            let formatted = formatResult(
                conversation: conversation,
                messages: filteredMessages,
                headerFormatter: headerFormatter,
                messageFormatter: messageFormatter
            )
            results.append(formatted)
        }

        return results
    }

    private static func conversationHasImage(messages: [Message]) -> Bool {
        for message in messages {
            let attachments = sdb.attachment(for: message.objectId)
            if attachments.contains(where: { $0.type == "image" }) {
                return true
            }
        }
        return false
    }

    private static func formatResult(
        conversation: Conversation,
        messages: [Message],
        headerFormatter: DateFormatter,
        messageFormatter: DateFormatter
    ) -> String {
        let title = conversation.title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? String(localized: "Conversation")
        let headerFormat = String(
            localized: "%@ • %@"
        )
        let header = String(format: headerFormat, title, headerFormatter.string(from: conversation.creation))

        let limitedMessages = messages.prefix(10)

        let body = limitedMessages.map { message -> String in
            let roleDescription: String = switch message.role {
            case .user:
                String(localized: "User")
            case .assistant:
                String(localized: "Assistant")
            default:
                message.role.rawValue.capitalized
            }

            let timestamp = messageFormatter.string(from: message.creation)
            var contents = message.document.trimmingCharacters(in: .whitespacesAndNewlines)
            if contents.isEmpty {
                contents = message.reasoningContent.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if contents.isEmpty {
                contents = String(localized: "(No Content)")
            }

            let entryHeaderFormat = String(
                localized: "[%@] %@"
            )
            let entryHeader = String(format: entryHeaderFormat, timestamp, roleDescription)

            return [entryHeader, contents].joined(separator: "\n")
        }

        let result = ([header] + body).joined(separator: "\n\n")
        return result
    }

    private static func dateRange(from components: DateComponents?) -> (start: Date, end: Date)? {
        guard let components else { return nil }
        let calendar = Calendar.current
        guard let targetDate = calendar.date(from: components) else { return nil }
        let start = calendar.startOfDay(for: targetDate)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return (start, end)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Message {
    func matches(keyword: String) -> Bool {
        let lowercasedKeyword = keyword.lowercased()
        if document.lowercased().contains(lowercasedKeyword) { return true }
        if reasoningContent.lowercased().contains(lowercasedKeyword) { return true }
        return false
    }
}
