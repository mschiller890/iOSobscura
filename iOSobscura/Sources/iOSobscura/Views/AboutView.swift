import SwiftUI

/// Reproduces the website's own footer content (GitHub / Stats / Donate
/// links) plus the community Discord invite shown on its error page, as a
/// dedicated tab rather than a row of links at the bottom of Home - a
/// native adaptation of the same three pieces of content, not an addition.
struct AboutView: View {
    private let githubURL = URL(string: "https://github.com/CatsLover2006/iOSobscuraServer")!
    private let donateURL = URL(string: "https://www.paypal.com/donate/?business=D5W2ZA2D5M8JA&no_recurring=0&item_name=Help+keep+iphoneosobscura.litten.ca+online%21&currency_code=CAD")!
    private let discordURL = URL(string: "https://discord.gg/rTJ9zxjMu3")!
    private let websiteURL = URL(string: "https://iosapps.litten.ca/")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Legacy iOS App Finder")
                            .font(.headline)
                        Text("An unofficial native client for the public iOSobscuraServer instance at iosapps.litten.ca. Not affiliated with Apple or the developers of any archived app.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Community") {
                    Link(destination: websiteURL) {
                        Label("Open iosapps.litten.ca", systemImage: "safari")
                    }
                    Link(destination: githubURL) {
                        Label("iOSobscuraServer on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: discordURL) {
                        Label("Join the iOS Obscura Discord", systemImage: "person.3")
                    }
                }

                Section {
                    Link(destination: donateURL) {
                        Label("Donate to This Instance", systemImage: "heart")
                    }
                } footer: {
                    Text("Donations support the server operator's hosting costs for this community instance, via PayPal.")
                }

                Section("App") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersionString)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("About")
        }
    }

    private var appVersionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }
}
