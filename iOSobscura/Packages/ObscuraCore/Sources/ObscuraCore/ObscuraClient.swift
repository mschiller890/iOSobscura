import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Talks to the public iosapps.litten.ca instance and hands back parsed
/// models. Every route here is one this app actually observed the live
/// server answer (see `ObscuraEndpoint`); there is no private or
/// undocumented endpoint in use.
public actor ObscuraClient {
    public static let shared = ObscuraClient()

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchHome() async throws -> [ObscuraAppSection] {
        let html = try await fetchHTML(ObscuraEndpoint.home)
        return ObscuraParser.parseAppSections(fromHTML: html)
    }

    public func search(query: String) async throws -> [ObscuraApp] {
        let html = try await fetchHTML(ObscuraEndpoint.search(query: query))
        if ObscuraParser.isNotFoundPage(html) { throw ObscuraError.notFound }
        return ObscuraParser.parseAppSections(fromHTML: html).first?.apps ?? []
    }

    public func fetchAppDetail(bundleID: String) async throws -> AppDetail {
        let html = try await fetchHTML(ObscuraEndpoint.appVersions(bundleID: bundleID))
        return try ObscuraParser.parseAppDetail(fromHTML: html, bundleID: bundleID)
    }

    public func fetchVersionDetail(bundleID: String, version: String) async throws -> VersionDetail {
        let html = try await fetchHTML(ObscuraEndpoint.appVersionLinks(bundleID: bundleID, version: version))
        return try ObscuraParser.parseVersionDetail(fromHTML: html, bundleID: bundleID, version: version)
    }

    public func fetchStats() async throws -> ServerStats {
        let html = try await fetchHTML(ObscuraEndpoint.stats)
        return ObscuraParser.parseServerStats(fromHTML: html)
    }

    /// Fetches raw bytes for an icon, following the redirect `/getAppIcon`
    /// issues to Apple's artwork CDN. Callers (the icon view) retry against
    /// `/getProxiedAppIcon` on failure, exactly like the website's own
    /// `onerror` fallback.
    public func fetchImageData(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ObscuraError.invalidResponse
        }
        return data
    }

    private func fetchHTML(_ url: URL) async throws -> String {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: URLRequest(url: url))
        } catch {
            throw ObscuraError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ObscuraError.invalidResponse
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw ObscuraError.parsingFailed("response was not UTF-8")
        }
        return html
    }
}
