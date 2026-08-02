import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case server(String)
    var errorDescription: String? {
        switch self { case .invalidResponse: "The server returned an unexpected response."; case .server(let message): message }
    }
}

struct APIClient: Sendable {
    static let baseURL = URL(string: "https://stitchly-application.vercel.app")!
    let token: String?
    private let decoder: JSONDecoder = {
        let value = JSONDecoder(); value.keyDecodingStrategy = .convertFromSnakeCase; value.dateDecodingStrategy = .iso8601; return value
    }()

    func request<T: Decodable>(_ path: String, method: String = "GET", body: (any Encodable)? = nil) async throws -> T {
        var request = URLRequest(url: Self.baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            let message = (try? JSONDecoder().decode(ServerError.self, from: data).error) ?? "Request failed (\(http.statusCode))."
            throw APIError.server(message)
        }
        if T.self == EmptyResponse.self { return EmptyResponse() as! T }
        return try decoder.decode(T.self, from: data)
    }

    func uploadPDF(_ fileURL: URL, userID: String) async throws -> BlobResponse {
        let access = fileURL.startAccessingSecurityScopedResource(); defer { if access { fileURL.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: fileURL)
        guard data.count <= 25 * 1024 * 1024 else { throw APIError.server("Choose a PDF smaller than 25 MB.") }
        let safeName = fileURL.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "pattern.pdf"
        let pathname = "patterns/\(userID)/\(safeName)"
        struct TokenEvent: Encodable { let type = "blob.generate-client-token"; let payload: Payload; struct Payload: Encodable { let pathname: String; let clientPayload: String? = nil; let multipart = false } }
        let tokenResponse: UploadTokenResponse = try await request("/api/patterns/upload", method: "POST", body: TokenEvent(payload: .init(pathname: pathname)))
        let parts = tokenResponse.clientToken.split(separator: "_")
        guard parts.count > 3 else { throw APIError.invalidResponse }
        var components = URLComponents(string: "https://vercel.com/api/blob/")!; components.queryItems = [.init(name: "pathname", value: pathname)]
        var upload = URLRequest(url: components.url!); upload.httpMethod = "PUT"; upload.httpBody = data
        upload.setValue("Bearer \(tokenResponse.clientToken)", forHTTPHeaderField: "Authorization")
        upload.setValue(String(parts[3]), forHTTPHeaderField: "x-vercel-blob-store-id")
        upload.setValue("12", forHTTPHeaderField: "x-api-version")
        upload.setValue("private", forHTTPHeaderField: "x-vercel-blob-access")
        upload.setValue("application/pdf", forHTTPHeaderField: "x-content-type")
        let (responseData, response) = try await URLSession.shared.data(for: upload)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw APIError.server("The PDF upload failed.") }
        return try decoder.decode(BlobResponse.self, from: responseData)
    }
}

private struct ServerError: Decodable { let error: String }
struct EmptyResponse: Codable { init() {} }
private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void
    init(_ value: any Encodable) { encodeValue = value.encode }
    func encode(to encoder: Encoder) throws { try encodeValue(encoder) }
}
