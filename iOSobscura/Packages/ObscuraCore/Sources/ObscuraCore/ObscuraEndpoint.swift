import Foundation

/// URLs for the public iOSobscuraServer instance this app talks to. There is
/// no JSON API - every one of these returns the same server-rendered HTML a
/// browser gets, which `ObscuraParser` reads back into models. Routes and
/// their query/path shapes were confirmed by requesting them directly:
/// `/`, `/searchPost?search=`, `/getAppVersions/{bundleID}`,
/// `/getAppVersionLinks/{bundleID}/{version}`, `/getAppIcon/{bundleID}`,
/// `/getProxiedAppIcon/{bundleID}` and `/stats`.
public enum ObscuraEndpoint {
    public static let baseURL = URL(string: "https://iosapps.litten.ca")!

    public static var home: URL { baseURL }

    public static func search(query: String) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("searchPost"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "search", value: query)]
        return components.url!
    }

    public static func appVersions(bundleID: String) -> URL {
        baseURL.appendingPathComponent("getAppVersions").appendingPathComponent(bundleID)
    }

    public static func appVersionLinks(bundleID: String, version: String) -> URL {
        baseURL
            .appendingPathComponent("getAppVersionLinks")
            .appendingPathComponent(bundleID)
            .appendingPathComponent(version)
    }

    public static func appIcon(bundleID: String) -> URL {
        baseURL.appendingPathComponent("getAppIcon").appendingPathComponent(bundleID)
    }

    public static func proxiedAppIcon(bundleID: String) -> URL {
        baseURL.appendingPathComponent("getProxiedAppIcon").appendingPathComponent(bundleID)
    }

    public static var stats: URL { baseURL.appendingPathComponent("stats") }

    /// Extracts a `getAppVersions/{bundleID}` path (with or without a
    /// leading slash, as the home page omits it and every other page
    /// includes it) into just the bundle ID.
    public static func bundleID(fromAppVersionsHref href: String) -> String? {
        guard let range = href.range(of: "getAppVersions/") else { return nil }
        let remainder = href[range.upperBound...]
        return remainder.isEmpty ? nil : String(remainder)
    }
}
