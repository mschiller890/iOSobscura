import Foundation

/// Typed navigation values for the Browse tab's `NavigationStack`. Kept as
/// distinct types (rather than pushing bare `String`s for both a bundle ID
/// and a version) so `navigationDestination(for:)` can never confuse one
/// for the other.
struct AppRoute: Hashable {
    let bundleID: String
}

struct VersionRoute: Hashable {
    let bundleID: String
    let appName: String
    let version: String
}
