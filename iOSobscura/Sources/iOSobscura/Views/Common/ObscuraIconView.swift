import SwiftUI
import UIKit
import ObscuraCore

/// A tiny in-memory icon cache. Icons are fetched from Apple's artwork CDN
/// (via the server's `/getAppIcon` redirect) or the server's own proxy, and
/// the same bundle ID is drawn repeatedly while scrolling grids and lists,
/// so this avoids re-downloading on every reappearance.
@MainActor
final class IconCache {
    static let shared = IconCache()
    private let cache = NSCache<NSString, UIImage>()

    func image(for key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func store(_ image: UIImage, for key: String) { cache.setObject(image, forKey: key as NSString) }
}

/// Mirrors the website's own fallback behaviour exactly: `<img src="/getAppIcon/{id}"
/// onerror="this.src='/getProxiedAppIcon/{id}'">`. Tries the direct Apple
/// artwork redirect first, then the server's own proxy, then a placeholder.
struct ObscuraIconView: View {
    let bundleID: String
    var size: CGFloat = 57

    @State private var uiImage: UIImage?
    @State private var failed = false

    // The 15.625% corner radius matches `.appIcon{border-radius:15.625%}`
    // from the site's own stylesheet at /getCSS.
    private var cornerRadius: CGFloat { size * 0.15625 }

    var body: some View {
        ZStack {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                if !failed {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Image(systemName: "app.dashed")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: bundleID) { await load() }
    }

    private func load() async {
        uiImage = nil
        failed = false
        if let cached = IconCache.shared.image(for: bundleID) {
            uiImage = cached
            return
        }
        let candidates = [
            ObscuraEndpoint.appIcon(bundleID: bundleID),
            ObscuraEndpoint.proxiedAppIcon(bundleID: bundleID),
        ]
        for url in candidates {
            if Task.isCancelled { return }
            if let data = try? await ObscuraClient.shared.fetchImageData(url), let image = UIImage(data: data) {
                IconCache.shared.store(image, for: bundleID)
                uiImage = image
                return
            }
        }
        failed = true
    }
}
