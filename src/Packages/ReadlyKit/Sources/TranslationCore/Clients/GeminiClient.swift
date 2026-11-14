import Foundation

struct GeminiClient: LLMClient {
    let apiKey: String
    let model: String
    let transport: any HTTPTransport

    private static let baseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models")!

    func complete(system: String, user: String) async throws -> String {
        let body = Body(
            systemInstruction: .init(role: nil, parts: [.init(text: system)]),
            contents: [.init(role: "user", parts: [.init(text: user)])]
        )
        let response = try await JSONEndpoint(transport: transport).post(
            body,
            to: Self.baseURL.appending(path: "\(model):generateContent"),
            headers: ["x-goog-api-key": apiKey],
            expecting: Response.self
        )
        let text = response.candidates?.first?.content?.parts?.compactMap(\.text).joined() ?? ""
        guard !text.isEmpty else { throw TranslationError.emptyResponse }
        return text
    }

    private struct Part: Codable { let text: String? }

    private struct Content: Codable {
        let role: String?
        let parts: [Part]?
    }

    private struct Body: Encodable {
        let systemInstruction: Content
        let contents: [Content]

        enum CodingKeys: String, CodingKey {
            case contents
            case systemInstruction = "system_instruction"
        }
    }

    private struct Response: Decodable {
        struct Candidate: Decodable { let content: Content? }
        let candidates: [Candidate]?
    }
}
