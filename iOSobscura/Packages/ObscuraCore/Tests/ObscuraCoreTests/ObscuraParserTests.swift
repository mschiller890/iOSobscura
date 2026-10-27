import XCTest
@testable import ObscuraCore

/// These fixtures are trimmed-down copies of real responses captured from
/// the live iosapps.litten.ca while building this app (head/script
/// boilerplate removed, structure otherwise untouched), so the parser is
/// tested against the server's actual markup rather than an imagined one.
final class ObscuraParserTests: XCTestCase {

    // MARK: - Home page / search sections

    func testParseHomeSectionsExtractsBothLabeledGroups() {
        let html = """
        <body class="pinstripe"><panel><fieldset><div><div><center><strong>Legacy iOS App Finder Homepage</strong></center></div></div></fieldset>\
        <label>Featured Apps</label><fieldset class="iconList">\
        <a href="getAppVersions/com.google.ios.youtube"><div><div><img loading="lazy" class="appIcon" src="getAppIcon/com.google.ios.youtube" onerror="this.onerror=null;this.src='/getProxiedAppIcon/com.google.ios.youtube'"><center>YouTube: Watch,...</center></div></div></a>\
        <a href="getAppVersions/com.atebits.tweetie2"><div><div><img loading="lazy" class="appIcon" src="getAppIcon/com.atebits.tweetie2"><center>Twitter</center></div></div></a>\
        </fieldset>\
        <label>Some Apps</label><fieldset class="iconList">\
        <a href="getAppVersions/nl.hedgerunner.iphowned"><div><div><img loading="lazy" class="appIcon" src="getAppIcon/nl.hedgerunner.iphowned"><center>iPhowned</center></div></div></a>\
        </fieldset>\
        <fieldset><a href="https://github.com/CatsLover2006/iOSobscuraServer"><div><div>Check out the Github</div></div></a></fieldset>\
        </panel></body>
        """

        let sections = ObscuraParser.parseAppSections(fromHTML: html)

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].title, "Featured Apps")
        XCTAssertEqual(sections[0].apps.map(\.bundleID), ["com.google.ios.youtube", "com.atebits.tweetie2"])
        XCTAssertEqual(sections[0].apps[0].cardTitle, "YouTube: Watch,...")
        XCTAssertEqual(sections[1].title, "Some Apps")
        XCTAssertEqual(sections[1].apps.map(\.bundleID), ["nl.hedgerunner.iphowned"])
    }

    func testParseAppCardsAcceptsLeadingSlashVariant() {
        // Every page except the homepage links with a leading slash.
        let html = #"<a href="/getAppVersions/com.celeski.willyou"><div><div><img src="/getAppIcon/com.celeski.willyou"><center>Will You?</center></div></div></a>"#
        let cards = ObscuraParser.parseAppCards(fromHTML: html)
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].bundleID, "com.celeski.willyou")
        XCTAssertEqual(cards[0].cardTitle, "Will You?")
    }

    // MARK: - /getAppVersions/{bundleID}

    func testParseAppDetailExtractsNameDeveloperAndVersions() throws {
        let html = """
        <title>YouTube: Watch, Listen, Stream</title>\
        <body class="pinstripe"><panel><fieldset><div><div style="height:57px;overflow:hidden"><img loading="lazy" class="appIcon" src="/getAppIcon/com.google.ios.youtube"><strong style="padding:.5em 0;line-height:57px"><center>YouTube: Watch, List...</center></strong></div></div><div><div>Google LLC</div></div><a href="javascript:history.back()"><div><div>Go Back</div></div></a></fieldset>\
        <label>Versions</label><fieldset>\
        <a href="/getAppVersionLinks/com.google.ios.youtube/1.0.0"><div><div>1.0.0</div></div></a>\
        <a href="/getAppVersionLinks/com.google.ios.youtube/1.0.1"><div><div>1.0.1</div></div></a>\
        <a href="/getAppVersionLinks/com.google.ios.youtube/15.43.4"><div><div>15.43.4</div></div></a>\
        </fieldset></panel></body>
        """

        let detail = try ObscuraParser.parseAppDetail(fromHTML: html, bundleID: "com.google.ios.youtube")

        XCTAssertEqual(detail.name, "YouTube: Watch, Listen, Stream")
        XCTAssertEqual(detail.developer, "Google LLC")
        XCTAssertEqual(detail.versions.map(\.version), ["1.0.0", "1.0.1", "15.43.4"])
    }

    func testParseAppDetailThrowsNotFoundFor404Page() {
        let html = """
        <title>Error 404</title><body><panel><fieldset><div><div><strong><center>Error 404</center></strong></div></div>\
        <div><div>That location doesn't exist.</div></div></fieldset></panel></body>
        """
        XCTAssertThrowsError(try ObscuraParser.parseAppDetail(fromHTML: html, bundleID: "nonexistent.bundle.id")) { error in
            XCTAssertEqual(error as? ObscuraError, .notFound)
        }
    }

    // MARK: - /getAppVersionLinks/{bundleID}/{version}

    func testParseVersionDetailExtractsRequirementAndMirrors() throws {
        let html = """
        <title>YouTube: Watch, Listen, Stream 1.0.0</title>\
        <body><panel><fieldset><div><div style="overflow:auto">Version 1.0.0<span style="float:right">Requires iOS 4.3</span></div></div></fieldset>\
        <label>#1, archive.org, Untestedioscollection, SSL<br>Supports: ARMv7 </label>\
        <fieldset><a href="https://archive.org/download/Untestedioscollection/YouTube%201.0.0%20(1).ipa"><div><div>Direct Download <small style="font-size:x-small">5.5MB</small></div></div></a></fieldset>\
        <label>#2, archive.org, Untestedioscollection, SSL<br>Supports: ARMv7 (Encrypted) </label>\
        <fieldset><a href="https://archive.org/download/Untestedioscollection/YouTube%201.0.0.ipa"><div><div>Direct Download <small style="font-size:x-small">8.9MB</small></div></div></a></fieldset>\
        </panel></body>
        """

        let detail = try ObscuraParser.parseVersionDetail(fromHTML: html, bundleID: "com.google.ios.youtube", version: "1.0.0")

        XCTAssertEqual(detail.requiresIOS, "4.3")
        XCTAssertEqual(detail.links.count, 2)

        let first = detail.links[0]
        XCTAssertEqual(first.index, 1)
        XCTAssertEqual(first.source, "archive.org")
        XCTAssertEqual(first.collection, "Untestedioscollection")
        XCTAssertEqual(first.tags, ["SSL"])
        XCTAssertEqual(first.supports, "ARMv7")
        XCTAssertEqual(first.sizeText, "5.5MB")
        XCTAssertEqual(first.url.absoluteString, "https://archive.org/download/Untestedioscollection/YouTube%201.0.0%20(1).ipa")

        let second = detail.links[1]
        XCTAssertEqual(second.index, 2)
        XCTAssertEqual(second.supports, "ARMv7 (Encrypted)")
        XCTAssertEqual(second.sizeText, "8.9MB")
    }

    func testParseVersionDetailIgnoresLabelsWithoutDownloadAnchors() throws {
        // The relocation-banner fieldset has no <label> before it, but guard
        // against a future stray label/fieldset pair with no anchor inside.
        let html = """
        <title>App 1.0</title><label>Not a mirror</label><fieldset><div><div>nothing to see here</div></div></fieldset>
        """
        let detail = try ObscuraParser.parseVersionDetail(fromHTML: html, bundleID: "x", version: "1.0")
        XCTAssertTrue(detail.links.isEmpty)
    }

    // MARK: - /stats

    func testParseServerStats() {
        let html = """
        <label>Stats</label><fieldset>\
        <div><div style="overflow:auto">App Count<span style="float:right">21234</span></div></div>\
        <div><div style="overflow:auto">Version Count<span style="float:right">33493</span></div></div>\
        <div><div style="overflow:auto">URL Count<span style="float:right">48773</span></div></div>\
        </fieldset>\
        <label>Your Device</label><fieldset>\
        <div><div style="overflow:auto">iOS Device?<span style="float:right">No</span></div></div>\
        <div><div style="overflow:auto">macOS Device?<span style="float:right">No</span></div></div>\
        <div><div style="overflow:auto">Searchable App Count<span style="float:right">21234</span></div></div>\
        <div><div style="overflow:auto">Searchable Version Count<span style="float:right">33493</span></div></div>\
        <div><div style="overflow:auto">Searchable URL Count<span style="float:right">48773</span></div></div>\
        </fieldset>
        """

        let stats = ObscuraParser.parseServerStats(fromHTML: html)

        XCTAssertEqual(stats.appCount, 21234)
        XCTAssertEqual(stats.versionCount, 33493)
        XCTAssertEqual(stats.urlCount, 48773)
        XCTAssertEqual(stats.isIOSDevice, false)
        XCTAssertEqual(stats.isMacDevice, false)
        XCTAssertEqual(stats.searchableAppCount, 21234)
        XCTAssertEqual(stats.searchableVersionCount, 33493)
        XCTAssertEqual(stats.searchableURLCount, 48773)
    }

    // MARK: - Error page detection

    func testIsNotFoundPage() {
        XCTAssertTrue(ObscuraParser.isNotFoundPage("<title>Error 404</title>"))
        XCTAssertTrue(ObscuraParser.isNotFoundPage("<div>That location doesn't exist.</div>"))
        XCTAssertFalse(ObscuraParser.isNotFoundPage("<title>YouTube</title>"))
    }

    // MARK: - Entity decoding

    func testDecodeHTMLEntities() {
        XCTAssertEqual(ObscuraParser.decodeHTMLEntities("Tom &amp; Jerry"), "Tom & Jerry")
        XCTAssertEqual(ObscuraParser.decodeHTMLEntities("It&#39;s"), "It's")
        XCTAssertEqual(ObscuraParser.decodeHTMLEntities("caf&#x65;"), "cafe")
        XCTAssertEqual(ObscuraParser.decodeHTMLEntities("no entities here"), "no entities here")
    }
}

extension ObscuraError: Equatable {
    public static func == (lhs: ObscuraError, rhs: ObscuraError) -> Bool {
        switch (lhs, rhs) {
        case (.notFound, .notFound): return true
        case (.invalidResponse, .invalidResponse): return true
        case (.network(let a), .network(let b)): return a == b
        case (.parsingFailed(let a), .parsingFailed(let b)): return a == b
        default: return false
        }
    }
}
