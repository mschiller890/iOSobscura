import Foundation
import ObscuraCore

// `swift test` cannot run on this machine: the Swift 6.4 toolchain here was
// lifted out of a container image (see repository README) and has no
// libIndexStore, which SwiftPM's automatic test-discovery entry point
// requires even with `--disable-index-store`. The proper XCTest suite in
// `Tests/ObscuraCoreTests` is still the source of truth and runs wherever a
// complete toolchain is available (Xcode, or a non-container Linux swift.org
// toolchain). This is a second, narrower check: the same assertions made
// with plain `precondition`, built and run with nothing but `swift run`, so
// the parsing logic is still genuinely exercised on this machine rather than
// only type-checked.

var failures = 0

@MainActor
func check(_ name: String, _ condition: @autoclosure () -> Bool) {
    if condition() {
        print("ok   - \(name)")
    } else {
        print("FAIL - \(name)")
        failures += 1
    }
}

// MARK: - Home sections

let homeHTML = """
<label>Featured Apps</label><fieldset class="iconList">\
<a href="getAppVersions/com.google.ios.youtube"><div><div><img loading="lazy" class="appIcon" src="getAppIcon/com.google.ios.youtube"><center>YouTube: Watch,...</center></div></div></a>\
<a href="getAppVersions/com.atebits.tweetie2"><div><div><img src="getAppIcon/com.atebits.tweetie2"><center>Twitter</center></div></div></a>\
</fieldset>\
<label>Some Apps</label><fieldset class="iconList">\
<a href="getAppVersions/nl.hedgerunner.iphowned"><div><div><img src="getAppIcon/nl.hedgerunner.iphowned"><center>iPhowned</center></div></div></a>\
</fieldset>
"""
let sections = ObscuraParser.parseAppSections(fromHTML: homeHTML)
check("home: two sections", sections.count == 2)
check("home: featured apps count", sections.first?.apps.count == 2)
check("home: first bundle id", sections.first?.apps.first?.bundleID == "com.google.ios.youtube")
check("home: second section title", sections.last?.title == "Some Apps")

// MARK: - App detail

let detailHTML = """
<title>YouTube: Watch, Listen, Stream</title>\
<div><div style="height:57px;overflow:hidden"><img src="/getAppIcon/x"><strong><center>YouTube</center></strong></div></div><div><div>Google LLC</div></div>\
<label>Versions</label><fieldset>\
<a href="/getAppVersionLinks/com.google.ios.youtube/1.0.0"><div><div>1.0.0</div></div></a>\
<a href="/getAppVersionLinks/com.google.ios.youtube/15.43.4"><div><div>15.43.4</div></div></a>\
</fieldset>
"""
do {
    let detail = try ObscuraParser.parseAppDetail(fromHTML: detailHTML, bundleID: "com.google.ios.youtube")
    check("detail: name", detail.name == "YouTube: Watch, Listen, Stream")
    check("detail: developer", detail.developer == "Google LLC")
    check("detail: version count", detail.versions.count == 2)
    check("detail: last version", detail.versions.last?.version == "15.43.4")
} catch {
    check("detail: parsed without throwing (\(error))", false)
}

do {
    _ = try ObscuraParser.parseAppDetail(fromHTML: "<title>Error 404</title>", bundleID: "x")
    check("detail: 404 page throws", false)
} catch {
    check("detail: 404 page throws", true)
}

// MARK: - Version detail

let versionHTML = """
<title>YouTube 1.0.0</title>\
<div style="overflow:auto">Version 1.0.0<span style="float:right">Requires iOS 4.3</span></div>\
<label>#1, archive.org, Untestedioscollection, SSL<br>Supports: ARMv7 </label>\
<fieldset><a href="https://archive.org/download/x/YouTube%201.0.0%20(1).ipa"><div><div>Direct Download <small>5.5MB</small></div></div></a></fieldset>\
<label>#2, archive.org, Untestedioscollection, SSL<br>Supports: ARMv7 (Encrypted) </label>\
<fieldset><a href="https://archive.org/download/x/YouTube%201.0.0.ipa"><div><div>Direct Download <small>8.9MB</small></div></div></a></fieldset>
"""
do {
    let versionDetail = try ObscuraParser.parseVersionDetail(fromHTML: versionHTML, bundleID: "com.google.ios.youtube", version: "1.0.0")
    check("version: requires iOS", versionDetail.requiresIOS == "4.3")
    check("version: link count", versionDetail.links.count == 2)
    check("version: first source", versionDetail.links.first?.source == "archive.org")
    check("version: first supports", versionDetail.links.first?.supports == "ARMv7")
    check("version: second supports", versionDetail.links.last?.supports == "ARMv7 (Encrypted)")
    check("version: first size", versionDetail.links.first?.sizeText == "5.5MB")
} catch {
    check("version: parsed without throwing (\(error))", false)
}

// MARK: - Stats

let statsHTML = """
<div style="overflow:auto">App Count<span style="float:right">21234</span></div>\
<div style="overflow:auto">Version Count<span style="float:right">33493</span></div>\
<div style="overflow:auto">URL Count<span style="float:right">48773</span></div>\
<div style="overflow:auto">iOS Device?<span style="float:right">No</span></div>
"""
let stats = ObscuraParser.parseServerStats(fromHTML: statsHTML)
check("stats: app count", stats.appCount == 21234)
check("stats: version count", stats.versionCount == 33493)
check("stats: url count", stats.urlCount == 48773)
check("stats: is iOS device", stats.isIOSDevice == false)

// MARK: - Result

print("")
if failures == 0 {
    print("All checks passed.")
    exit(0)
} else {
    print("\(failures) check(s) FAILED.")
    exit(1)
}
