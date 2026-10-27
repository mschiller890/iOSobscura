import SwiftUI
import ObscuraCore

/// A tab with no equivalent on the website at all - the site only ever
/// links straight to a mirror's URL. Once "Direct Download" became a real
/// in-app download (see `DownloadLinkRow`), somewhere to see what's
/// downloading and what finished stopped being optional.
struct DownloadsView: View {
    private let manager = DownloadManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if manager.activeDownloads.isEmpty && manager.completedDownloads.isEmpty {
                    EmptyStateView(
                        systemImage: "arrow.down.circle",
                        title: "No Downloads",
                        message: "Start a download from any version's mirrors and it will show up here."
                    )
                } else {
                    List {
                        if !manager.activeDownloads.isEmpty {
                            Section("Downloading") {
                                ForEach(manager.activeDownloads) { download in
                                    ActiveDownloadRow(download: download)
                                }
                            }
                        }
                        if !manager.completedDownloads.isEmpty {
                            Section("Downloaded") {
                                ForEach(manager.completedDownloads) { record in
                                    CompletedDownloadRow(record: record)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Downloads")
        }
    }
}

private struct ActiveDownloadRow: View {
    let download: ActiveDownload
    private let manager = DownloadManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(download.appName)
                        .font(.subheadline.weight(.medium))
                    Text("\(download.version) · \(download.sourceLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if case .failed = download.phase {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            switch download.phase {
            case .downloading(let written, let total):
                if let total, total > 0 {
                    ProgressView(value: Double(written), total: Double(total))
                } else {
                    ProgressView()
                }
                HStack {
                    if let total, total > 0 {
                        Text("\(bytes(written)) of \(bytes(total))")
                    } else {
                        Text(bytes(written))
                    }
                    Spacer()
                    if let speed = download.bytesPerSecond, speed > 0 {
                        Text(formattedTransferRate(speed))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                Button("Cancel", role: .destructive) { manager.cancel(download) }
                    .font(.caption)

            case .failed(let message, _):
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Button("Retry") { manager.retry(download) }
                    Button("Dismiss", role: .destructive) { manager.dismissFailed(download) }
                }
                .font(.caption.weight(.medium))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }
}

private struct CompletedDownloadRow: View {
    let record: DownloadRecord
    private let manager = DownloadManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.zipper")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.appName)
                    .font(.subheadline.weight(.medium))
                Text("\(record.version) · \(record.sourceLabel)\(sizeSuffix)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(record.completedAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            ShareLink(item: manager.fileURL(for: record)) {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.borderless)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) { manager.delete(record) }
        }
        .contextMenu {
            ShareLink(item: manager.fileURL(for: record))
            Button("Delete", role: .destructive) { manager.delete(record) }
        }
        .accessibilityElement(children: .combine)
    }

    private var sizeSuffix: String {
        guard let bytes = record.fileSizeBytes else { return "" }
        return " · " + ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
