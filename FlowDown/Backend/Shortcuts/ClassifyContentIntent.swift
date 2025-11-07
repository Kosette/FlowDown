import AppIntents
import Foundation

struct ClassifyContentIntent: AppIntent {
    static var title: LocalizedStringResource {
        LocalizedStringResource("Classify Content")
    }

    static var description = IntentDescription(
        LocalizedStringResource(
            "Use the model to classify content into one of the provided candidates. If the model cannot decide, the first candidate is returned."
        )
    )

    @Parameter(
        title: LocalizedStringResource("Prompt")
    )
    var prompt: String

    @Parameter(
        title: LocalizedStringResource("Content"),
        requestValueDialog: IntentDialog("What content should be classified?")
    )
    var content: String

    @Parameter(
        title: LocalizedStringResource("Candidates"),
        requestValueDialog: IntentDialog("Provide the candidate labels.")
    )
    var candidates: [String]

    static var parameterSummary: some ParameterSummary {
        Summary("Classify \(\.$content)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { throw FlowDownShortcutError.emptyMessage }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        let sanitizedCandidates = candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let primaryCandidate = sanitizedCandidates.first else {
            throw FlowDownShortcutError.invalidCandidates
        }

        let candidateList = sanitizedCandidates.enumerated()
            .map { index, value in
                "\(index + 1). \(value)"
            }
            .joined(separator: "\n")

        let baseInstruction = String(
            localized: "You are a classification assistant. Choose the best candidate for the provided content."
        )

        let outputInstructionFormat = String(
            localized: "Respond with exactly one candidate string from the list above. If you are unsure, respond with '%@'."
        )
        let outputInstruction = String(format: outputInstructionFormat, primaryCandidate)

        var instructionSegments: [String] = [
            baseInstruction,
        ]

        if !trimmedPrompt.isEmpty {
            instructionSegments.append(trimmedPrompt)
        }

        instructionSegments.append(String(localized: "Candidates:"))
        instructionSegments.append(candidateList)
        instructionSegments.append(String(localized: "Content:"))
        instructionSegments.append(trimmedContent)
        instructionSegments.append(outputInstruction)

        let classificationPrompt = instructionSegments.joined(separator: "\n\n")

        let response = try await InferenceIntentHandler.execute(
            model: nil,
            message: classificationPrompt,
            image: nil,
            options: .init(allowsImages: false)
        )

        let normalized = response
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"'")))
            ?? ""

        let resolved = sanitizedCandidates.first {
            $0.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        } ?? primaryCandidate

        let dialog = IntentDialog(.init(stringLiteral: resolved))
        return .result(value: resolved, dialog: dialog)
    }
}
