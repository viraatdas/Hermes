import Foundation
import Security

@MainActor
class AnthropicService: ObservableObject {
    static let shared = AnthropicService()

    @Published private(set) var hasAPIKey = false
    @Published var lastError: String?

    private let keychainService = "com.hermes.anthropic"
    private let model = "claude-sonnet-4-5-20250929"
    private let anthropicVersion = "2023-06-01"

    private init() {
        hasAPIKey = loadAPIKey() != nil
    }

    var credentialSourceDescription: String {
        hasAPIKey ? "Stored in macOS Keychain" : "No local Anthropic key found"
    }

    func saveAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "apiKey"
        ]

        SecItemDelete(query as CFDictionary)

        var item = query
        item[kSecValueData as String] = data
        SecItemAdd(item as CFDictionary, nil)
        hasAPIKey = true
        lastError = nil
    }

    func clearAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "apiKey"
        ]
        SecItemDelete(query as CFDictionary)
        hasAPIKey = false
    }

    @discardableResult
    func importLocalCredentials() -> Bool {
        if loadAPIKey() != nil {
            hasAPIKey = true
            lastError = nil
            return true
        }

        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
           !envKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveAPIKey(envKey)
            return true
        }

        lastError = "No local ANTHROPIC_API_KEY was available to import."
        return false
    }

    func testConnection() async throws -> String {
        try await complete(
            system: "You are a terse API connectivity checker.",
            prompt: "Reply with: Connected",
            maxTokens: 32
        )
    }

    func answerQuestion(question: String, title: String, notes: String, transcript: String) async throws -> String {
        let prompt = """
        Meeting: \(title)

        Current editable notes:
        \(trim(notes, limit: 8_000))

        Conversation transcript so far:
        \(trim(transcript, limit: 18_000))

        Question:
        \(question)

        Answer using only the notes and transcript above. If the answer is not present yet, say that clearly.
        """

        return try await complete(
            system: "You answer questions about an in-progress meeting. Be concise, cite uncertainty, and never invent details.",
            prompt: prompt,
            maxTokens: 700
        )
    }

    func generateNotes(title: String, currentNotes: String, transcript: String) async throws -> String {
        let prompt = """
        Meeting: \(title)

        Current user notes:
        \(trim(currentNotes, limit: 8_000))

        Transcript:
        \(trim(transcript, limit: 22_000))

        Create editable meeting notes in Markdown with these sections:
        # \(title)

        ## Summary
        ## Action Items
        ## Decisions
        ## Open Questions
        ## Raw Notes

        Preserve useful manual notes from Current user notes. Use checkboxes for action items. Do not include text outside Markdown.
        """

        return try await complete(
            system: "You turn meeting transcripts into concise, editable Markdown notes. Preserve user-authored details.",
            prompt: prompt,
            maxTokens: 1_500
        )
    }

    private func complete(system: String, prompt: String, maxTokens: Int) async throws -> String {
        guard let apiKey = loadAPIKey() else {
            throw AnthropicError.missingAPIKey
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")

        let body = AnthropicRequest(
            model: model,
            max_tokens: maxTokens,
            system: system,
            messages: [
                AnthropicMessage(role: "user", content: prompt)
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            lastError = message
            throw AnthropicError.requestFailed(message)
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let text = decoded.content.compactMap { part -> String? in
            part.type == "text" ? part.text : nil
        }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        if text.isEmpty {
            throw AnthropicError.emptyResponse
        }

        lastError = nil
        return text
    }

    private func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "apiKey",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else {
            return nil
        }
        return key
    }

    private func trim(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.suffix(limit))
    }
}

private struct AnthropicRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [AnthropicMessage]
}

private struct AnthropicMessage: Encodable {
    let role: String
    let content: String
}

private struct AnthropicResponse: Decodable {
    let content: [AnthropicContent]
}

private struct AnthropicContent: Decodable {
    let type: String
    let text: String?
}

enum AnthropicError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add an Anthropic API key in Settings before using AI notes."
        case .invalidResponse:
            return "Anthropic returned an invalid response."
        case .emptyResponse:
            return "Anthropic returned an empty response."
        case .requestFailed(let message):
            return message
        }
    }
}
