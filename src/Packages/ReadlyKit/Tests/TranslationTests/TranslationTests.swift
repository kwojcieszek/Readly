import Foundation
import Testing
@testable import TranslationCore
@testable import SystemTranslation

private final class MockTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    private let status: Int
    private let body: String

    init(status: Int = 200, body: String) {
        self.status = status
        self.body = body
    }

    var lastRequest: URLRequest? { lock.withLock { recorded.last } }

    var lastJSON: [String: Any] {
        let data = lastRequest?.httpBody ?? Data()
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { recorded.append(request) }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

@Suite struct LLMClientTests {
    @Test func anthropicSendsMessagesRequestAndReadsTextBlocks() async throws {
        let transport = MockTransport(body: """
        {"content":[{"type":"thinking","thinking":""},{"type":"text","text":"dzień dobry"}],"stop_reason":"end_turn"}
        """)
        let client = try #require(LLMClientFactory.makeClient(for: .anthropic, apiKey: "sk-test", model: "", transport: transport))
        let answer = try await client.complete(system: "sys", user: "hello")

        #expect(answer == "dzień dobry")
        let request = try #require(transport.lastRequest)
        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-test")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(transport.lastJSON["model"] as? String == "claude-opus-5-5")
        #expect(transport.lastJSON["system"] as? String == "sys")
        #expect(transport.lastJSON["max_tokens"] as? Int == 4096)
    }

    @Test func anthropicReportsRefusals() async throws {
        let transport = MockTransport(body: #"{"content":[],"stop_reason":"refusal"}"#)
        let client = try #require(LLMClientFactory.makeClient(for: .anthropic, apiKey: "k", model: "m", transport: transport))
        await #expect(throws: TranslationError.refused) {
            try await client.complete(system: "s", user: "u")
        }
    }

    @Test func openAISendsChatCompletion() async throws {
        let transport = MockTransport(body: #"{"choices":[{"message":{"role":"assistant","content":"hola"}}]}"#)
        let client = try #require(LLMClientFactory.makeClient(for: .openAI, apiKey: "sk-o", model: "gpt-x", transport: transport))
        #expect(try await client.complete(system: "sys", user: "hello") == "hola")

        let request = try #require(transport.lastRequest)
        #expect(request.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
        #expect(request.value(forHTTPHeaderField: "authorization") == "Bearer sk-o")
        #expect(transport.lastJSON["model"] as? String == "gpt-x")
        #expect((transport.lastJSON["messages"] as? [[String: String]])?.map { $0["role"] } == ["system", "user"])
    }

    @Test func geminiSendsGenerateContent() async throws {
        let transport = MockTransport(body: #"{"candidates":[{"content":{"role":"model","parts":[{"text":"bon"},{"text":"jour"}]}}]}"#)
        let client = try #require(LLMClientFactory.makeClient(for: .gemini, apiKey: "g-key", model: "gemini-test", transport: transport))
        #expect(try await client.complete(system: "sys", user: "hello") == "bonjour")

        let request = try #require(transport.lastRequest)
        #expect(request.url?.absoluteString
            == "https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent")
        #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "g-key")
        #expect(transport.lastJSON["system_instruction"] != nil)
    }

    @Test(arguments: TranslationProviderKind.allCases.filter(\.usesAPIKey))
    func surfacesProviderErrorMessages(provider: TranslationProviderKind) async throws {
        let transport = MockTransport(status: 401, body: #"{"error":{"message":"Invalid API key","type":"auth"}}"#)
        let client = try #require(LLMClientFactory.makeClient(for: provider, apiKey: "bad", model: "m", transport: transport))
        await #expect(throws: TranslationError.http(status: 401, message: "Invalid API key")) {
            try await client.complete(system: "s", user: "u")
        }
    }
}

@Suite struct TranslatorTests {
    @Test func wordPromptCarriesContextAndLanguage() {
        let request = TranslationRequest(kind: .word, text: "bank", context: "We sat on the river bank.", targetLanguage: "Polish")
        let prompt = TranslationPromptBuilder().prompt(for: request)
        #expect(prompt.system.contains("Polish"))
        #expect(prompt.user.contains("\"bank\""))
        #expect(prompt.user.contains("We sat on the river bank."))
    }

    @Test func sentencePromptContainsText() {
        let request = TranslationRequest(kind: .sentence, text: "Nobody came.", targetLanguage: "German")
        let prompt = TranslationPromptBuilder().prompt(for: request)
        #expect(prompt.user.contains("Nobody came."))
        #expect(prompt.user.contains("German"))
    }

    @Test func factoryRequiresAnAPIKey() {
        let factory = TranslatorFactory(keyStore: InMemoryAPIKeyStore())
        #expect(throws: TranslationError.missingAPIKey(.gemini)) {
            _ = try factory.makeTranslator(provider: .gemini, model: "")
        }
    }

    @Test func translatorTrimsTheAnswer() async throws {
        let transport = MockTransport(body: #"{"choices":[{"message":{"content":"  kot \n"}}]}"#)
        let factory = TranslatorFactory(keyStore: InMemoryAPIKeyStore(keys: [.openAI: "k"]), transport: transport)
        let translator = try factory.makeTranslator(provider: .openAI, model: "")
        let request = TranslationRequest(kind: .word, text: "cat", targetLanguage: "Polish")
        #expect(try await translator.translate(request) == "kot")
        #expect(transport.lastJSON["model"] as? String == TranslationProviderKind.openAI.defaultModel)
    }
}

@Suite struct TranslationOutputTests {
    @Test func plainAnswerHasNoGlossary() {
        let output = TranslationOutput(parsing: "  kot \n")
        #expect(output == TranslationOutput(text: "kot"))
    }

    @Test func splitsTranslationFromGlossary() {
        let answer = """
        He understood only one thing —
        this was not an ordinary place.
        ---
        zwykły = ordinary, common, usual
        - miejsce = place, location
        Miejsce = spot
        not an entry
        """
        let output = TranslationOutput(parsing: answer)
        #expect(output.text == "He understood only one thing —\nthis was not an ordinary place.")
        #expect(output.glossary == [
            GlossaryEntry(term: "zwykły", meanings: "ordinary, common, usual"),
            GlossaryEntry(term: "miejsce", meanings: "place, location"),
        ])
    }

    @Test func passagePromptAsksForAGlossary() {
        let request = TranslationRequest(kind: .sentence, text: "Nobody came.", targetLanguage: "German")
        #expect(TranslationPromptBuilder().prompt(for: request).user.contains(TranslationOutput.separator))
    }
}

@Suite struct SystemTranslatorTests {
    @Test func usesTheBookLanguageUnlessItEqualsTheTarget() {
        let polish = Locale.Language(identifier: "pl")
        #expect(SystemTranslator.source("en-US", target: polish)?.languageCode == .english)
        #expect(SystemTranslator.source("pl", target: polish) == nil)
        #expect(SystemTranslator.source(nil, target: polish) == nil)
        #expect(SystemTranslator.source("", target: polish) == nil)
    }

    @Test func appleProviderNeedsNoKeyButAHost() {
        let factory = TranslatorFactory(keyStore: InMemoryAPIKeyStore())
        #expect(!TranslationProviderKind.apple.usesAPIKey)
        #expect(throws: TranslationError.systemTranslationUnavailable) {
            _ = try factory.makeTranslator(provider: .apple, model: "")
        }
    }
}
