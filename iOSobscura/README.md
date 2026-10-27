# iOS Obscura (client app)

A native SwiftUI client for **[iosapps.litten.ca](https://iosapps.litten.ca/)** - "Legacy iOS
App Finder," a community-run instance of the open-source
[iOSobscuraServer](https://github.com/CatsLover2006/iOSobscuraServer). The server is a
directory of old iOS apps and their archived `.ipa` versions, pulled mostly from
archive.org mirrors. This app is an unofficial client, not affiliated with Apple, the
server operator, or the developers of any archived app.

There is no JSON API. Every screen in this app talks to the same server-rendered HTML
routes a browser would hit, and reads them back into models with a small, deliberately
narrow HTML scraper (`ObscuraParser`) tuned to the exact markup the live server returns.

## What the website does (as inspected)

Routes confirmed by requesting them directly against the live server:

| Route | Returns |
|---|---|
| `GET /` | Home page: "Featured Apps" and "Some Apps" icon grids, a search form, a relocation banner, and footer links (GitHub, `/stats`, PayPal donate) |
| `GET /searchPost?search={query}` | A "Search Results" icon grid in the same markup as the home sections |
| `GET /getAppVersions/{bundleID}` | One app's name, developer, and its list of archived version numbers |
| `GET /getAppVersionLinks/{bundleID}/{version}` | That version's iOS requirement and every mirror (source, collection, tags like `SSL`, architecture support, file size, direct download URL) |
| `GET /getAppIcon/{bundleID}` | 308-redirects to the app's icon on Apple's artwork CDN |
| `GET /getProxiedAppIcon/{bundleID}` | The same icon, proxied by the server - the page's own `onerror` fallback when the direct redirect fails |
| `GET /stats` | Server-wide app/version/URL counts, plus a "Your Device" section the server computes per-request |
| any unknown path | A normal `200` page titled "Error 404" (not an HTTP 404) with a community Discord invite |

Any route not in this table (`/icon*`, `/getCSS`, the w3counter analytics script) was
inspected but isn't relevant to a native client with its own icon and no need for the
page's own stylesheet - except that `/getCSS`'s `.appIcon{border-radius:15.625%}` rule is
reproduced exactly in `ObscuraIconView` so icons are shaped the same as on the website.

## Architecture

```
iOSobscura/
├── Package.swift                  the app (SwiftUI, iOS 17+), depends on ObscuraCore
├── xtool.yml, Info.plist          bundle config, app icon wiring
├── Resources/                     app icon source + make-icons.py generator
├── Sources/iOSobscura/            SwiftUI views and @Observable view models
│   └── Downloads/                 DownloadManager (background URLSession) + the Downloads tab
└── Packages/ObscuraCore/          a SEPARATE local SwiftPM package (see below)
    ├── Sources/ObscuraCore/       models, endpoints, HTML parser, networking - Foundation only
    ├── Sources/ObscuraCoreSelfTest/   plain-executable sanity check (see Testing)
    └── Tests/ObscuraCoreTests/    the XCTest suite of record
```

`ObscuraCore` is pure Foundation - no UIKit, no SwiftUI - and is its own package rather
than just a second target of the app's `Package.swift`. That split exists for one reason:
SwiftUI does not exist on Linux at all, so a second *target* in the same package would
still have to be built by `swift test` to discover tests, and would still fail. A separate
package with its own `Package.swift`, consumed by the app via a local path dependency, is
what actually lets this machine build and (mostly) test the app's logic for real. See
`Packages/ObscuraCore/Package.swift` for the full reasoning.

Everything that fetches or parses a page lives in `ObscuraCore`:

- `ObscuraEndpoint` - the eight routes above, as typed URL builders
- `ObscuraParser` - pure `String -> model` functions, one per route, plus the label-splitting
  logic for a mirror's `"#1, archive.org, Untestedioscollection, SSL<br>Supports: ARMv7"` text
- `ObscuraClient` - an `actor` that fetches a route and hands its HTML to the parser
- `Models.swift` - `ObscuraApp`, `AppDetail`, `DownloadLink`, `VersionDetail`, `ServerStats`

The app target (`Sources/iOSobscura`) is SwiftUI only: a `TabView` with four tabs (Browse,
Downloads, Stats, About), each a `NavigationStack`, each content screen backed by a small
`@Observable` view model that holds a `LoadState<T>` (`idle` / `loading` / `loaded` /
`failed`) and nothing else. Navigation uses typed route values (`AppRoute`, `VersionRoute`
in `Routes.swift`) rather than raw strings, specifically so a bundle ID and a version
number - both plain strings - can never be confused by `navigationDestination(for:)`.

**Downloads** (`Sources/iOSobscura/Downloads/`) has no equivalent on the website at all -
the site only ever links straight to a mirror's URL. `DownloadLinkRow`'s "Download" button
starts a real download through `DownloadManager`, which uses a **background**
`URLSession` (identifier `com.mschiller890.iosobscura.downloads`) so it keeps running while
the app is suspended. The one thing that makes that actually survive a relaunch: the
session is recreated with the same identifier *eagerly*, from `AppDelegate.didFinishLaunching`
(not lazily from whichever view happens to ask for it first), which is what makes iOS hand
back the same `URLSessionTask` for anything still in flight - and since nothing else
survives a relaunch, every fact needed to rebuild that download's row (app name, version,
mirror label, final filename) is stashed as JSON on the task's own `taskDescription` when
it starts. Finished files land in `Documents/Downloads/`, exposed to the Files app via
`UIFileSharingEnabled`/`LSSupportsOpeningDocumentsInPlace` in `Info.plist` so a sideloading
tool can reach them through Share or "Open In," and their metadata (not the bytes) is
mirrored to a small JSON index in Application Support so the Downloads tab survives a
relaunch too.

## Environment this was built and verified on

- **Fedora Linux 44**, no Mac, no iOS Simulator (SwiftUI does not exist on Linux at all).
- **xtool 1.21.0** at `~/.local/bin/xtool`.
- **Darwin SDK installed** (`xtool sdk status`): path
  `~/.swiftpm/swift-sdks/darwin.artifactbundle`, SDK version **27.0** (read from that
  bundle's `iPhoneOS.sdk/SDKSettings.json`).
- **Swift 6.4** toolchain at `~/.local/swift-6.4/usr/bin`, required because the Darwin SDK
  carries Apple Swift 6.4 modules. It is not an official swift.org tarball (those 404 for
  6.4 on Linux); it was extracted from the `docker.io/library/swift:6.4.0-rhel-ubi10`
  container image onto this machine before this session.
- Neither of the above is on the default `PATH`; every command below assumes:
  ```bash
  export PATH="$HOME/.local/swift-6.4/usr/bin:$HOME/.local/bin:$PATH"
  ```
- **No iOS device was connected during this work** (`xtool devices --usb --no-wait`
  returned nothing). The app was never installed, launched, or visually inspected on a
  simulator or device - see Limitations.

This setup was not configured during this session; it already existed, set up the same
way for an unrelated reference project (`~/Documents/technowizz26`, not modified by this
work). That project's `AGENTS.md`/`setup-environment.sh` were read (never edited) to learn
the toolchain's actual location and the fact that an iOS device binary needs an explicit
`-platform_version` linker flag to pick up the installed SDK's design language - see
`Package.swift`'s comment above `iOSSDKVersion` for why, and "Verified facts" below for how
that was independently confirmed rather than taken on trust.

## Build commands (verified)

Run from this directory (`iOSobscura/`), after exporting `PATH` as above:

```bash
xtool dev build          # -> xtool/iOSobscura.app   (Mach-O arm64 iOS executable)
xtool dev build --ipa    # -> xtool/iOSobscura.ipa   (unsigned, 1.2MB, 19 files)
```

Both were run in this session and succeeded on the **first attempt** - this machine's
xtool/SDK/toolchain setup needed no fixes. **Checked:**

```
$ file xtool/iOSobscura.app/iOSobscura
xtool/iOSobscura.app/iOSobscura: Mach-O 64-bit arm64 executable, flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|BINDS_TO_WEAK|PIE>
```

`otool` doesn't exist on Linux, so the binary's `LC_BUILD_VERSION` load command (the thing
the `-platform_version` linker flag is supposed to set) was verified by parsing the Mach-O
header directly with a short Python script reading the raw load commands:

```
LC_BUILD_VERSION found:
  platform: iOS
  minos (deployment target): 17.0.0
  sdk: 27.0.0
```

That confirms the linker flag in `Package.swift` actually reached the binary - the app
will get the current iOS design language on a real phone, not whatever the deployment
target alone would imply.

**Not run, and not claimed to work:**
- `xtool dev run` / `xtool install` / `xtool launch` - no simulator exists on Linux and no
  device was connected this session.
- `xtool dev build --sign` - requires `xtool auth` (an Apple ID login), a credential
  decision left to whoever has an Apple account to use, not something to attempt
  unattended. The shipped artifact is an **unsigned** IPA, installable via a sideloading
  tool such as TrollStore, or re-signable by whoever has a certificate.

## Testing (what actually ran, and what didn't)

`swift test` inside `Packages/ObscuraCore` **fails**, but not because of a code problem:

```
error: Test discovery was requested, but failed to lookup index store library in toolchain
```

Every source file compiles cleanly first (the build reaches `ObscuraCoreTests-product`
before failing) - this toolchain, lifted from a container image rather than installed
properly, is simply missing `libIndexStore`/`libclang`, which SwiftPM's automatic
test-discovery entry point needs even with `--disable-index-store`. This is a toolchain
gap, confirmed by trying both the default and `--disable-index-store` paths and getting
the same failure either way.

Worked around with `Sources/ObscuraCoreSelfTest`: a plain executable target with no
XCTest dependency, running the same assertions against the same real-site HTML fixtures
with `precondition`-style checks. **This one actually runs, on this machine, right now:**

```
$ swift run ObscuraCoreSelfTest
ok   - home: two sections
ok   - home: featured apps count
... (18 checks total)
All checks passed.
```

The proper XCTest suite, `Tests/ObscuraCoreTests/ObscuraParserTests.swift` (9 test
methods, fixtures trimmed from real captured responses), is the suite of record for CI or
a Mac/Xcode - it type-checks here but **has not been executed anywhere in this session**.
Say so plainly rather than claim it passed: that's the same distinction
`~/Documents/technowizz26/AGENTS.md` draws for its own UI test suite, which needs a
simulator this machine doesn't have either.

The SwiftUI layer (`Sources/iOSobscura`) has **no test coverage and no runtime
verification at all** - it is build-verified only (`xtool dev build` type-checks and links
it against the real Darwin SDK, producing a running Mach-O binary) and has never been
installed, launched, or looked at on a screen.

## Feature checklist (website -> app)

| Website feature | In the app | Where | Tested |
|---|---|---|---|
| Home page icon grids ("Featured Apps", "Some Apps") | Yes | `HomeView` (Browse tab) | Parser: yes (self-test + XCTest). Screen: build-verified only |
| Search | Yes, as native `.searchable` (debounced) instead of a separate page | `HomeView` | Parser: yes. Screen: build-verified only |
| App detail: name, developer, version list | Yes | `AppDetailView` | Parser: yes. Screen: build-verified only |
| Version detail: iOS requirement, mirrors, sizes, architecture tags | Yes | `VersionLinksView` / `DownloadLinkRow` | Parser: yes. Screen: build-verified only |
| Direct download link | Yes - starts a real, backgrounded in-app download instead of opening a browser; "Open in Browser" and "Copy Link" are kept as secondary actions on the same URL | `DownloadLinkRow` / `DownloadManager` | Build-verified only |
| Downloads tab (Downloading + Downloaded sections) | **Native-only addition, no website equivalent** - the site never does more than link to a mirror | `DownloadsView` | Build-verified only |
| Icon with `onerror` proxy fallback | Yes, same two-step fallback, plus in-memory caching | `ObscuraIconView` | Build-verified only |
| `/stats` page | Yes | `StatsView` (Stats tab) | Parser: yes. Screen: build-verified only |
| GitHub / Donate footer links | Yes, as its own tab rather than a page footer | `AboutView` | Build-verified only |
| Discord invite (shown on the site's 404 page) | Yes, moved into `AboutView` since it's community content, not an error-page-specific action | `AboutView` | Build-verified only |
| 404 handling | Yes - `ObscuraParser.isNotFoundPage` / `ObscuraError.notFound`, surfaced through each screen's existing error state | Every fetch path | Parser: yes (self-test + XCTest) |
| Relocation banner ("site has moved to iosapps.litten.ca") | **Not implemented, by decision** - stale content about a historical domain change; this app always talks to the canonical host, so the banner has nothing to tell it | - | - |
| Favicons (`/icon`, `/icon32`, `/icon16`) | N/A - the app has its own icon | - | - |
| Full ~21k-app catalog browsing beyond the home page's curated lists | Not implemented - the website's own home page doesn't do this either; the only way to reach most apps is search, which the app does support | - | - |
| Search result pagination | Not implemented - no pagination control was observed in the one query inspected; unverified whether the server paginates beyond that | - | - |

## Known limitations

- **Never run.** No simulator (Linux has none) and no device was connected this session.
  Everything SwiftUI is build-verified only - it compiles, links, and produces a real
  arm64 Mach-O binary, and that is the full extent of what was checked.
- **Unsigned.** `--sign` needs an Apple ID via `xtool auth`; left to whoever runs this with
  their own account.
- **`swift test` does not run** in this environment (missing `libIndexStore` in the
  container-derived toolchain) - see Testing above for the workaround and what's actually
  covered by it versus only type-checked.
- **Mirror-label parsing is best-effort.** `ObscuraParser`'s split of
  `"#1, archive.org, Untestedioscollection, SSL<br>Supports: ARMv7"` into structured fields
  was verified against the specific samples this app fetched, not against the full ~33k
  version catalog; it falls back to showing the raw label text rather than crashing if a
  future label doesn't match the expected shape.
- **Stats screen device fields are the server's own computation** for whatever request the
  app happens to send - not spoofed, not reinterpreted locally.
- **The background-download machinery is reasoned, not checked.** `DownloadManager`'s
  reattachment-after-relaunch logic, the `taskDescription`-as-storage trick, and the
  `handleEventsForBackgroundURLSession` wake-up path are all standard, documented
  `URLSession` behavior - but with no simulator or device available this session, none of
  it has actually been exercised: no download has run, finished, failed, been retried, or
  survived an app relaunch for real. The same is true of the Files app integration
  (`UIFileSharingEnabled`/`LSSupportsOpeningDocumentsInPlace`) - it builds, it has not been
  looked at on a device.

## Regenerating the app icon

```bash
python3 -I Resources/make-icons.py
```

Draws one 1024x1024 master (a grid of app-icon squares behind a magnifying glass - a nod
to the site's own icon grids and search field, not a copy of any app's actual artwork)
and resizes it to every size `Info.plist`'s `CFBundleIcons`/`CFBundleIcons~ipad` names.
