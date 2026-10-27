import Foundation

/// Reads the server-rendered HTML iosapps.litten.ca returns for each route
/// back into `ObscuraCore` models. There is no JSON API to decode, so this
/// is a small, deliberately narrow scraper tuned to the exact markup the
/// server was observed to emit - not a general HTML parser. Every pattern
/// here was matched against a real response captured from the live site
/// before being written.
///
/// Every public function is a pure string -> model transform with no I/O,
/// which is what lets `ObscuraCoreTests` run on this Linux machine even
/// though SwiftUI (and the app that uses it) cannot build here at all.
public enum ObscuraParser {

    // MARK: - Shared error page

    /// The server answers an unknown route with a normal 200 page titled
    /// "Error 404" rather than an HTTP 404 status (confirmed against
    /// `/robots.txt`, which does not exist on this server). Callers should
    /// check this before parsing a page for its expected content.
    public static func isNotFoundPage(_ html: String) -> Bool {
        html.contains("<title>Error 404</title>") || html.contains("That location doesn&#39;t exist.") || html.contains("That location doesn't exist.")
    }

    // MARK: - Home page / search results

    /// Parses one or more `<label>Title</label><fieldset class="iconList">…</fieldset>`
    /// groups, as seen on the home page ("Featured Apps", "Some Apps") and
    /// on `/searchPost` ("Search Results").
    public static func parseAppSections(fromHTML html: String) -> [ObscuraAppSection] {
        let sectionPattern = #"<label>([^<]*)</label>\s*<fieldset class="iconList">(.*?)</fieldset>"#
        return allMatches(of: sectionPattern, in: html, options: [.dotMatchesLineSeparators]).map { groups in
            let title = decodeHTMLEntities(groups[0] ?? "")
            let body = groups[1] ?? ""
            return ObscuraAppSection(title: title, apps: parseAppCards(fromHTML: body))
        }
    }

    /// Parses `<a href="…getAppVersions/{bundleID}">…<img …><center>Name</center>…</a>`
    /// entries. Used both for the labeled sections above and directly on the
    /// `/searchPost` results fieldset.
    public static func parseAppCards(fromHTML html: String) -> [ObscuraApp] {
        let cardPattern = #"<a href="([^"]*getAppVersions/[^"]+)">\s*<div>\s*<div>\s*<img[^>]*>\s*<center>([^<]*)</center>"#
        return allMatches(of: cardPattern, in: html, options: [.dotMatchesLineSeparators]).compactMap { groups in
            guard let href = groups[0], let bundleID = ObscuraEndpoint.bundleID(fromAppVersionsHref: href) else { return nil }
            let title = decodeHTMLEntities(groups[1] ?? "")
            return ObscuraApp(bundleID: bundleID, cardTitle: title)
        }
    }

    // MARK: - /getAppVersions/{bundleID}

    public static func parseAppDetail(fromHTML html: String, bundleID: String) throws -> AppDetail {
        if isNotFoundPage(html) { throw ObscuraError.notFound }

        guard let titleGroups = firstMatch(of: #"<title>([^<]*)</title>"#, in: html) else {
            throw ObscuraError.parsingFailed("missing <title>")
        }
        let name = decodeHTMLEntities(titleGroups[0] ?? "")

        let developer = firstMatch(
            of: #"</strong>\s*</div>\s*</div>\s*<div>\s*<div>([^<]*)</div>\s*</div>"#,
            in: html,
            options: [.dotMatchesLineSeparators]
        )?[0].map(decodeHTMLEntities)

        let versionPattern = #"getAppVersionLinks/[^"/]+/([^"]+)"[^>]*>\s*<div>\s*<div>([^<]*)</div>"#
        let versions = allMatches(of: versionPattern, in: html, options: [.dotMatchesLineSeparators]).compactMap { groups -> AppVersionSummary? in
            guard let raw = groups[0], let decoded = raw.removingPercentEncoding else { return nil }
            return AppVersionSummary(version: decoded)
        }

        return AppDetail(bundleID: bundleID, name: name, developer: developer, versions: versions)
    }

    // MARK: - /getAppVersionLinks/{bundleID}/{version}

    public static func parseVersionDetail(fromHTML html: String, bundleID: String, version: String) throws -> VersionDetail {
        if isNotFoundPage(html) { throw ObscuraError.notFound }

        let requiresIOS = firstMatch(of: #"Requires iOS ([^<]*)</span>"#, in: html)?[0].map(decodeHTMLEntities)

        // Each mirror is a `<label>…meta…<br>…supports…</label>` immediately
        // followed by a `<fieldset>` holding one or more direct-download
        // anchors. Everything up to the first `<label>Versions</label>`-style
        // marker on other pages is irrelevant here, so this just scans the
        // whole document for the label/fieldset pairs that contain a
        // "Direct Download" anchor.
        let blockPattern = #"<label>(.*?)</label>\s*<fieldset>(.*?)</fieldset>"#
        let blocks = allMatches(of: blockPattern, in: html, options: [.dotMatchesLineSeparators])

        var links: [DownloadLink] = []
        for groups in blocks {
            let rawLabel = groups[0] ?? ""
            let fieldsetBody = groups[1] ?? ""
            let anchorPattern = #"<a href="([^"]+)">\s*<div>\s*<div>\s*Direct Download\s*(?:<small[^>]*>([^<]*)</small>)?"#
            let anchors = allMatches(of: anchorPattern, in: fieldsetBody, options: [.dotMatchesLineSeparators])
            guard !anchors.isEmpty else { continue }

            let parsed = parseMirrorLabel(rawLabel)
            for anchorGroups in anchors {
                guard let urlString = anchorGroups[0], let url = URL(string: urlString) else { continue }
                let sizeText = anchorGroups[1].map(decodeHTMLEntities)
                links.append(DownloadLink(
                    index: parsed.index,
                    source: parsed.source,
                    collection: parsed.collection,
                    tags: parsed.tags,
                    supports: parsed.supports,
                    sizeText: sizeText,
                    rawLabel: decodeHTMLEntities(rawLabel.replacingOccurrences(of: "<br>", with: " ")),
                    url: url
                ))
            }
        }

        return VersionDetail(bundleID: bundleID, version: version, requiresIOS: requiresIOS, links: links)
    }

    /// Splits a label like
    /// `"#1, archive.org, Untestedioscollection, SSL<br>Supports: ARMv7 (Encrypted) "`
    /// into its parts. The format is consistent across every mirror observed
    /// on the live site, but this falls back to leaving fields `nil` rather
    /// than crashing if a future label doesn't match it.
    private static func parseMirrorLabel(_ rawLabel: String) -> (index: Int?, source: String?, collection: String?, tags: [String], supports: String?) {
        let parts = rawLabel.components(separatedBy: "<br>")
        let metaPart = decodeHTMLEntities(parts.first ?? "").trimmingCharacters(in: .whitespaces)
        let supportsPart = parts.count > 1 ? decodeHTMLEntities(parts[1]).trimmingCharacters(in: .whitespaces) : nil

        let tokens = metaPart.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
        var index: Int?
        var source: String?
        var collection: String?
        var tags: [String] = []

        if let first = tokens.first, first.hasPrefix("#") {
            index = Int(first.dropFirst())
        }
        if tokens.count > 1 { source = tokens[1] }
        if tokens.count > 2 { collection = tokens[2] }
        if tokens.count > 3 { tags = Array(tokens[3...]) }

        var supports: String?
        if let supportsPart, supportsPart.hasPrefix("Supports:") {
            supports = supportsPart.dropFirst("Supports:".count).trimmingCharacters(in: .whitespaces)
        } else {
            supports = supportsPart
        }
        if supports?.isEmpty == true { supports = nil }

        return (index, source, collection, tags, supports)
    }

    // MARK: - /stats

    public static func parseServerStats(fromHTML html: String) -> ServerStats {
        let pairPattern = #"([A-Za-z][A-Za-z ?]*?)<span style="float:right">([^<]*)</span>"#
        var values: [String: String] = [:]
        for groups in allMatches(of: pairPattern, in: html) {
            guard let label = groups[0], let value = groups[1] else { continue }
            values[label.trimmingCharacters(in: .whitespaces)] = value.trimmingCharacters(in: .whitespaces)
        }

        func int(_ key: String) -> Int? { values[key].flatMap { Int($0) } }
        func bool(_ key: String) -> Bool? {
            switch values[key] {
            case "Yes": return true
            case "No": return false
            default: return nil
            }
        }

        return ServerStats(
            appCount: int("App Count"),
            versionCount: int("Version Count"),
            urlCount: int("URL Count"),
            isIOSDevice: bool("iOS Device?"),
            isMacDevice: bool("macOS Device?"),
            searchableAppCount: int("Searchable App Count"),
            searchableVersionCount: int("Searchable Version Count"),
            searchableURLCount: int("Searchable URL Count")
        )
    }

    // MARK: - Regex helpers

    static func firstMatch(of pattern: String, in text: String, options: NSRegularExpression.Options = []) -> [String?]? {
        allMatches(of: pattern, in: text, options: options, limit: 1).first
    }

    static func allMatches(of pattern: String, in text: String, options: NSRegularExpression.Options = [], limit: Int = .max) -> [[String?]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var results: [[String?]] = []
        regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, stop in
            guard let match else { return }
            var groups: [String?] = []
            for i in 1..<match.numberOfRanges {
                let range = match.range(at: i)
                groups.append(range.location == NSNotFound ? nil : nsText.substring(with: range))
            }
            results.append(groups)
            if results.count >= limit { stop.pointee = true }
        }
        return results
    }

    /// Decodes the small set of HTML entities actually seen in server
    /// responses (ampersands in app names, apostrophes, CJK/emoji pass
    /// through untouched since the response body is already UTF-8).
    static func decodeHTMLEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }
        var result = string
        let named: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&nbsp;", " "),
        ]
        for (entity, replacement) in named {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        result = replacingNumericEntities(in: result)
        return result
    }

    private static func replacingNumericEntities(in string: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"&#x?([0-9A-Fa-f]+);"#) else { return string }
        let nsString = string as NSString
        var result = string
        let matches = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))
        for match in matches.reversed() {
            let whole = nsString.substring(with: match.range)
            let digits = nsString.substring(with: match.range(at: 1))
            let isHex = whole.lowercased().contains("#x")
            guard let scalarValue = UInt32(digits, radix: isHex ? 16 : 10),
                  let scalar = Unicode.Scalar(scalarValue) else { continue }
            result = (result as NSString).replacingCharacters(in: match.range, with: String(Character(scalar)))
        }
        return result
    }
}
