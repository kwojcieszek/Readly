import Foundation

struct AnthropicClient: LLMClient {
    let apiKey: String
    let model: String
    let transport: any HTTPTransport

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func complete(system: String, user: String) async throws -> String {
        let body = Body(
            model: model,
            maxTokens: 4096,
            system: system,
            messages: [.init(role: "user", content: user)],
            outputConfig: .init(effort: "low")
        )
        let response = try await JSONEndpoint(transport: transport).post(
            body,
            to: Self.endpoint,
            headers: ["x-api-key": apiKey, "anthropic-version": "2023-06-01"],
            expecting: Response.self
        )
        if response.stopReason == "refusal" { throw TranslationError.refused }
        let text = response.content.filter { $0.type == "text" }.compactMap(\.text).joined()
        guard !text.isEmpty else { throw TranslationError.emptyResponse }
        return text
    }

    private struct Body: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }
        /// Translation is a simple task: low effort keeps answers fast.
        struct OutputConfig: Encodable { let effort: String }

        let model: String
        let maxTokens: Int
        let system: String
        let messages: [Message]
        let outputConfig: OutputConfig

        enum CodingKeys: String, CodingKey {
            case model, system, messages
            case maxTokens = "max_tokens"
            case outputConfig = "output_config"
        }
    }

    private struct Response: Decodable {
        struct Block: Decodable {
            let type: String
            let text: String?
        }
        let content: [Block]
        let stopReason: String?

        enum CodingKeys: String, CodingKey {
            case content
            case stopReason = "stop_reason"
        }
    }
}
