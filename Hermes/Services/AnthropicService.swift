import Foundation
import Security
import AppKit

/// The AI provider a credential targets.
enum AIProvider: String, CaseIterable, Identifiable {
    case anthropic        // Anthropic API key (sk-ant-api...)
    case claudeCode       // Claude Code / claude.ai OAuth access token (sk-ant-oat...)
    case openai           // OpenAI / Codex API key (sk-...)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic API Key"
        case .claudeCode: return "Claude Code (OAuth)"
        case .openai: return "Codex / OpenAI"
        }
    }

    var placeholder: String {
        switch self {
        case .anthropic: return "sk-ant-api03-..."
        case .claudeCode: return "sk-ant-oat01-..."
        case .openai: return "sk-..."
        }
    }

    /// Keychain account key used to store this provider's secret.
    var keychainAccount: String {
        switch self {
        case .anthropic: return "apiKey"          // kept for backwards compatibility
        case .claudeCode: return "claudeCodeOAuth"
        case .openai: return "openaiApiKey"
        }
    }
}

/// Multi-provider credential store + completion brain.
///
/// Historically this was Anthropic-only; the public surface (`hasAPIKey`,
/// `saveAPIKey`, `clearAPIKey`, `importLocalCredentials`, `testConnection`,
/// `answerQuestion`, `generateNotes`) is preserved so existing call sites keep
/// working. It now also speaks Claude Code OAuth and OpenAI/Codex.
@MainActor
class AnthropicService: ObservableObject {
    static let shared = AnthropicService()

    /// True when the active provider has a usable credential.
    @Published private(set) var hasAPIKey = false
    @Published var lastError: String?
    @Published var activeProvider: AIProvider = .anthropic {
        didSet {
            UserDefaults.standard.set(activeProvider.rawValue, forKey: "aiActiveProvider")
            refreshState()
        }
    }

    private let keychainService = "com.hermes.anthropic"
    private let anthropicVersion = "2023-06-01"

    private init() {
        if let stored = UserDefaults.standard.string(forKey: "aiActiveProvider"),
           let provider = AIProvider(rawValue: stored) {
            activeProvider = provider
        }
        refreshState()
    }

    // MARK: - State

    /// Providers that currently have a stored credential.
    var configuredProviders: [AIProvider] {
        AIProvider.allCases.filter { loadCredential(for: $0) != nil }
    }

    var credentialSourceDescription: String {
        guard hasAPIKey else { return "No AI credential configured" }
        return "\(activeProvider.displayName) · stored in macOS Keychain"
    }

    func hasCredential(for provider: AIProvider) -> Bool {
        loadCredential(for: provider) != nil
    }

    private func refreshState() {
        hasAPIKey = loadCredential(for: activeProvider) != nil
    }

    // MARK: - Save / Clear

    func saveCredential(_ value: String, for provider: AIProvider) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: provider.keychainAccount
        ]
        SecItemDelete(query as CFDictionary)

        var item = query
        item[kSecValueData as String] = data
        SecItemAdd(item as CFDictionary, nil)

        activeProvider = provider   // also refreshes state
        lastError = nil
    }

    func clearCredential(for provider: AIProvider) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: provider.keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        refreshState()
    }

    // Backwards-compatible helpers (Anthropic API key).
    func saveAPIKey(_ key: String) { saveCredential(key, for: .anthropic) }
    func clearAPIKey() { clearCredential(for: activeProvider) }

    // MARK: - Local import

    /// Best-effort import of credentials already present on this machine.
    /// Sandbox blocks reading arbitrary home files, so this only covers
    /// environment variables. Use `importCredentialFile(at:)` for CLI configs.
    @discardableResult
    func importLocalCredentials() -> Bool {
        let env = ProcessInfo.processInfo.environment

        if let key = env["ANTHROPIC_API_KEY"], !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveCredential(key, for: .anthropic)
            return true
        }
        if let token = env["CLAUDE_CODE_OAUTH_TOKEN"], !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveCredential(token, for: .claudeCode)
            return true
        }
        if let key = env["OPENAI_API_KEY"], !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveCredential(key, for: .openai)
            return true
        }

        lastError = "No ANTHROPIC_API_KEY / CLAUDE_CODE_OAUTH_TOKEN / OPENAI_API_KEY found in the environment."
        return false
    }

    /// Parse a Claude Code (`~/.claude/.credentials.json`) or Codex
    /// (`~/.codex/auth.json`) credential file selected by the user.
    @discardableResult
    func importCredentialFile(at url: URL) -> Bool {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            lastError = "Could not read \(url.lastPathComponent)."
            return false
        }

        // Claude Code: { "claudeAiOauth": { "accessToken": "sk-ant-oat..." } }
        if let oauth = json["claudeAiOauth"] as? [String: Any],
           let token = oauth["accessToken"] as? String, !token.isEmpty {
            saveCredential(token, for: .claudeCode)
            lastError = nil
            return true
        }

        // Codex: { "OPENAI_API_KEY": "sk-..." }
        if let key = json["OPENAI_API_KEY"] as? String, !key.isEmpty {
            saveCredential(key, for: .openai)
            lastError = nil
            return true
        }

        // Generic fallbacks.
        if let key = json["accessToken"] as? String, key.hasPrefix("sk-ant-oat") {
            saveCredential(key, for: .claudeCode)
            lastError = nil
            return true
        }
        if let key = json["api_key"] as? String ?? json["apiKey"] as? String, !key.isEmpty {
            saveCredential(key, for: key.hasPrefix("sk-ant") ? .anthropic : .openai)
            lastError = nil
            return true
        }

        lastError = "No recognizable token found in \(url.lastPathComponent)."
        return false
    }

    // MARK: - Public completions

    func testConnection() async throws -> String {
        try await complete(
            system: "You are a terse API connectivity checker.",
            prompt: "Reply with exactly: Connected",
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

        Answer using only the notes and transcript above. If the answer is not present yet, say that clearly. When you reference something specific, quote the relevant phrase so it can be traced.
        """

        return try await complete(
            system: "You answer questions about an in-progress meeting. Be concise, cite uncertainty, quote sources, and never invent details.",
            prompt: prompt,
            maxTokens: 700
        )
    }

    func generateNotes(title: String, currentNotes: String, transcript: String) async throws -> String {
        let prompt = """
        Meeting: \(title)

        Current user notes (anchors):
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

        Preserve useful manual notes (anchors) from the user notes. Use checkboxes for action items. Do not include text outside Markdown.
        """

        return try await complete(
            system: "You turn meeting transcripts into concise, editable Markdown notes. Preserve user-authored details.",
            prompt: prompt,
            maxTokens: 1_500
        )
    }

    /// Lightweight private answer used by the stealth overlay.
    func quickAsk(_ question: String, context: String) async throws -> String {
        let prompt = """
        Live meeting context (notes + transcript):
        \(trim(context, limit: 16_000))

        Question or request from the user (this is private, the other participants cannot see it):
        \(question)

        Give a short, direct, immediately useful answer. If it's a request to draft something, draft it tightly.
        """
        return try await complete(
            system: "You are a discreet meeting copilot whispering to one participant in real time. Be brief and actionable.",
            prompt: prompt,
            maxTokens: 600
        )
    }

    // MARK: - Routing

    private func complete(system: String, prompt: String, maxTokens: Int) async throws -> String {
        guard let credential = loadCredential(for: activeProvider) else {
            throw AnthropicError.missingAPIKey
        }

        switch activeProvider {
        case .anthropic:
            return try await completeAnthropic(credential: credential, useOAuth: false, system: system, prompt: prompt, maxTokens: maxTokens)
        case .claudeCode:
            return try await completeAnthropic(credential: credential, useOAuth: true, system: system, prompt: prompt, maxTokens: maxTokens)
        case .openai:
            return try await completeOpenAI(apiKey: credential, system: system, prompt: prompt, maxTokens: maxTokens)
        }
    }

    private func completeAnthropic(credential: String, useOAuth: Bool, system: String, prompt: String, maxTokens: Int) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")

        if useOAuth {
            request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        } else {
            request.setValue(credential, forHTTPHeaderField: "x-api-key")
        }

        let body = AnthropicRequest(
            model: "claude-sonnet-4-5-20250929",
            max_tokens: maxTokens,
            system: system,
            messages: [AnthropicMessage(role: "user", content: prompt)]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AnthropicError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            lastError = message
            throw AnthropicError.requestFailed(message)
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let text = decoded.content.compactMap { $0.type == "text" ? $0.text : nil }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AnthropicError.emptyResponse }
        lastError = nil
        return text
    }

    private func completeOpenAI(apiKey: String, system: String, prompt: String, maxTokens: Int) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = OpenAIRequest(
            model: "gpt-4o-mini",
            max_tokens: maxTokens,
            messages: [
                OpenAIMessage(role: "system", content: system),
                OpenAIMessage(role: "user", content: prompt)
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AnthropicError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            lastError = message
            throw AnthropicError.requestFailed(message)
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        let text = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw AnthropicError.emptyResponse }
        lastError = nil
        return text
    }

    // MARK: - Keychain

    private func loadCredential(for provider: AIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: provider.keychainAccount,
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

// MARK: - Wire formats

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

private struct OpenAIRequest: Encodable {
    let model: String
    let max_tokens: Int
    let messages: [OpenAIMessage]
}

private struct OpenAIMessage: Encodable, Decodable {
    let role: String
    let content: String?
}

private struct OpenAIResponse: Decodable {
    let choices: [OpenAIChoice]
}

private struct OpenAIChoice: Decodable {
    let message: OpenAIMessage
}

enum AnthropicError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add an AI credential in Settings before using AI notes."
        case .invalidResponse:
            return "The AI provider returned an invalid response."
        case .emptyResponse:
            return "The AI provider returned an empty response."
        case .requestFailed(let message):
            return message
        }
    }
}
