import SwiftUI
import UIKit
import ObscuraCore

private struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .foregroundStyle(Color.accentColor)
    }
}

/// One mirror from `/getAppVersionLinks/{bundleID}/{version}`. The website
/// just links straight to the archive.org (or other) file; this keeps that
/// exact action as the primary button and adds Share/Copy as native
/// conveniences around the same link, not new workflows.
struct DownloadLinkRow: View {
    let link: DownloadLink

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let index = link.index {
                    Text("#\(index)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                Text(link.source ?? link.rawLabel)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let sizeText = link.sizeText {
                    Text(sizeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let collection = link.collection {
                Text(collection)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !link.tags.isEmpty || link.supports != nil {
                HStack(spacing: 6) {
                    ForEach(link.tags, id: \.self) { TagChip(text: $0) }
                    if let supports = link.supports {
                        TagChip(text: "Supports: \(supports)")
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    openURL(link.url)
                } label: {
                    Label("Direct Download", systemImage: "arrow.down.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                ShareLink(item: link.url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 6)
        .contextMenu {
            Button {
                UIPasteboard.general.string = link.url.absoluteString
            } label: {
                Label("Copy Link", systemImage: "doc.on.doc")
            }
            ShareLink(item: link.url)
        }
        .accessibilityElement(children: .combine)
    }
}
