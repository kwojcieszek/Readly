import Foundation

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw TranslationError.network("Unexpected response from the translation service.")
            }
            return (data, http)
        } catch let error as TranslationError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw TranslationError.network(error.localizedDescription)
        }
    }
}

/// Shared plumbing for JSON-over-POST LLM endpoints.
struct JSONEndpoint: Sendable {
    let transport: any HTTPTransport

    func post<Body: Encodable, Response: Decodable>(
        _ body: Body,
        to url: URL,
        headers: [String: String],
        expecting: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error.message
            throw TranslationError.http(status: response.statusCode, message: message ?? "")
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw TranslationError.emptyResponse
        }
    }

    /// OpenAI, Anthropic and Gemini all report errors as `{"error": {"message": ...}}`.
    private struct ErrorEnvelope: Decodable {
        struct Detail: Decodable { let message: String }
        let error: Detail
    }
}
