import Foundation
#if SWIFT_PACKAGE
import TerraCore
#endif

struct SolsticeRelease: Decodable, Sendable {
    let tagName: String
    let pageURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case pageURL = "html_url"
    }
}

enum UpdateChecker {
    enum CheckError: LocalizedError {
        case unavailable
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Публичные обновления пока недоступны. Репозиторий Solstice остаётся приватным."
            case .invalidResponse:
                return "Сервис обновлений вернул некорректный ответ. Попробуйте позже."
            }
        }
    }

    static func latestRelease() async throws -> SolsticeRelease {
        let url = URL(string: "https://api.github.com/repos/Oleg-Bar/Solstice/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json",forHTTPHeaderField: "Accept")
        request.setValue("Solstice/1.07",forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let (data,response) = try await URLSession(configuration: configuration).data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CheckError.invalidResponse }
        if http.statusCode == 404 { throw CheckError.unavailable }
        guard http.statusCode == 200 else { throw CheckError.invalidResponse }
        let release = try JSONDecoder().decode(SolsticeRelease.self,from: data)
        guard release.pageURL.scheme == "https", release.pageURL.host == "github.com" else {
            throw CheckError.invalidResponse
        }
        return release
    }
}
