import Foundation

struct OpenAIClient: LLMClient {
    let apiKey: String
    let model: String
    let transport: any HTTPTransport

    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func complete(system: String, user: String) async throws -> String {
        let body = Body(model: model, messages: [
            .init(role: "system", content: system),
            .init(role: "user", content: user),
        ])
        let response = try await JSONEndpoint(transport: transport).post(
            body,
            to: Self.endpoint,
            headers: ["authorization": "Bearer \(apiKey)"],
            expecting: Response.self
        )
        guard let text = response.choices.first?.message.content, !text.isEmpty else {
            throw TranslationError.emptyResponse
        }
        return text
    }

    private struct Body: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }
        let model: String
        let messages: [Message]
    }

    private struct Response: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }
}
