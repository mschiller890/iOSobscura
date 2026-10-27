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

/// One mirror from `/getAppVersionLinks/{bundleID}/{version}`. Where the
/// website just links straight to the file, "Download" here starts a real,
/// backgrounded in-app download (see `DownloadManager`) that shows up on
/// the Downloads tab; opening the raw link in a browser and copying it are
/// kept as secondary actions on the same URL.
struct DownloadLinkRow: View {
    let link: DownloadLink
    let bundleID: String
    let appName: String
    let version: String

    @Environment(\.openURL) private var openURL
    private let manager = DownloadManager.shared

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

            actionRow
                .padding(.top, 2)
        }
        .padding(.vertical, 6)
        .contextMenu {
            Button {
                openURL(link.url)
            } label: {
                Label("Open in Browser", systemImage: "safari")
            }
            Button {
                UIPasteboard.general.string = link.url.absoluteString
            } label: {
                Label("Copy Link", systemImage: "doc.on.doc")
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var actionRow: some View {
        if manager.isDownloaded(link) {
            Label("Downloaded", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        } else if let active = manager.activeDownload(for: link) {
            inlineProgress(active)
        } else {
            Button {
                manager.start(link: link, bundleID: bundleID, appName: appName, version: version)
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func inlineProgress(_ download: ActiveDownload) -> some View {
        switch download.phase {
        case .downloading(let written, let total):
            HStack(spacing: 8) {
                if let total, total > 0 {
                    ProgressView(value: Double(written), total: Double(total))
                        .frame(width: 90)
                } else {
                    ProgressView()
                        .frame(width: 20, height: 20)
                }
                if let speed = download.bytesPerSecond, speed > 0 {
                    Text("Downloading… \(formattedTransferRate(speed))")
                } else {
                    Text("Downloading…")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        case .failed:
            Label("Download Failed", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
