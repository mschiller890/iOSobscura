import Foundation

/// One app as it appears in a card: the home page's "Featured Apps" / "Some
/// Apps" sections, or a `/searchPost` results list. The server only ever
/// gives us the (sometimes truncated) card title here - the full name and
/// developer are only known once `/getAppVersions/{bundleID}` is fetched.
public struct ObscuraApp: Identifiable, Hashable, Sendable {
    public let bundleID: String
    public let cardTitle: String

    public init(bundleID: String, cardTitle: String) {
        self.bundleID = bundleID
        self.cardTitle = cardTitle
    }

    public var id: String { bundleID }
}

/// A labeled group of app cards, e.g. "Featured Apps" or "Search Results".
public struct ObscuraAppSection: Identifiable, Sendable {
    public let title: String
    public let apps: [ObscuraApp]
    public var id: String { title }

    public init(title: String, apps: [ObscuraApp]) {
        self.title = title
        self.apps = apps
    }
}

/// One entry in an app's version list.
public struct AppVersionSummary: Identifiable, Hashable, Sendable {
    public let version: String
    public var id: String { version }

    public init(version: String) {
        self.version = version
    }
}

/// The page returned by `/getAppVersions/{bundleID}`.
public struct AppDetail: Sendable {
    public let bundleID: String
    public let name: String
    public let developer: String?
    public let versions: [AppVersionSummary]

    public init(bundleID: String, name: String, developer: String?, versions: [AppVersionSummary]) {
        self.bundleID = bundleID
        self.name = name
        self.developer = developer
        self.versions = versions
    }
}

/// One mirror/source for a given version, as listed under
/// `/getAppVersionLinks/{bundleID}/{version}`. The server's label packs
/// several facts into one string of the form
/// `"#1, archive.org, Untestedioscollection, SSL<br>Supports: ARMv7 "`;
/// `ObscuraParser` splits that into these fields, falling back to the raw
/// label text when the format does not match.
public struct DownloadLink: Identifiable, Hashable, Sendable {
    public let id: String
    public let index: Int?
    public let source: String?
    public let collection: String?
    public let tags: [String]
    public let supports: String?
    public let sizeText: String?
    public let rawLabel: String
    public let url: URL

    public init(
        index: Int?,
        source: String?,
        collection: String?,
        tags: [String],
        supports: String?,
        sizeText: String?,
        rawLabel: String,
        url: URL
    ) {
        self.index = index
        self.source = source
        self.collection = collection
        self.tags = tags
        self.supports = supports
        self.sizeText = sizeText
        self.rawLabel = rawLabel
        self.url = url
        self.id = "\(rawLabel)#\(url.absoluteString)"
    }
}

/// The page returned by `/getAppVersionLinks/{bundleID}/{version}`.
public struct VersionDetail: Sendable {
    public let bundleID: String
    public let version: String
    public let requiresIOS: String?
    public let links: [DownloadLink]

    public init(bundleID: String, version: String, requiresIOS: String?, links: [DownloadLink]) {
        self.bundleID = bundleID
        self.version = version
        self.requiresIOS = requiresIOS
        self.links = links
    }
}

/// The page returned by `/stats`. Field names mirror the labels the server
/// prints; "searchable" counts are the server's own term for the subset it
/// considers indexable for this client.
public struct ServerStats: Sendable {
    public let appCount: Int?
    public let versionCount: Int?
    public let urlCount: Int?
    public let isIOSDevice: Bool?
    public let isMacDevice: Bool?
    public let searchableAppCount: Int?
    public let searchableVersionCount: Int?
    public let searchableURLCount: Int?

    public init(
        appCount: Int?,
        versionCount: Int?,
        urlCount: Int?,
        isIOSDevice: Bool?,
        isMacDevice: Bool?,
        searchableAppCount: Int?,
        searchableVersionCount: Int?,
        searchableURLCount: Int?
    ) {
        self.appCount = appCount
        self.versionCount = versionCount
        self.urlCount = urlCount
        self.isIOSDevice = isIOSDevice
        self.isMacDevice = isMacDevice
        self.searchableAppCount = searchableAppCount
        self.searchableVersionCount = searchableVersionCount
        self.searchableURLCount = searchableURLCount
    }
}
