import SwiftUI
import ObscuraCore

/// One card in the home page's icon grid - the native equivalent of the
/// website's `.iconList` entries (icon above a truncated, centered title).
struct AppCardView: View {
    let app: ObscuraApp

    var body: some View {
        VStack(spacing: 6) {
            ObscuraIconView(bundleID: app.bundleID, size: 60)
            Text(app.cardTitle)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .frame(height: 32)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
