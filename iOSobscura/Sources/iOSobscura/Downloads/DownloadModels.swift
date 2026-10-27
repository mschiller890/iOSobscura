import Foundation

/// Stashed on the `URLSessionDownloadTask.taskDescription` so a task can be
/// fully reconstructed after the app relaunches and reattaches to a
/// background session - the task itself is the only thing the OS hands
/// back, and it only carries a `String?`.
struct PendingDownloadInfo: Codable {
    let bundleID: String
    let appName: String
    let version: String
    let sourceLabel: String
    let suggestedFileName: String
    let remoteURL: URL
}

/// One finished download, persisted to disk so the Downloads tab survives
/// relaunches. The bytes themselves live alongside in
/// `DownloadManager.downloadsDirectory/{fileName}`.
struct DownloadRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let bundleID: String
    let appName: String
    let version: String
    let sourceLabel: String
    let remoteURL: URL
    let fileName: String
    let fileSizeBytes: Int64?
    let completedAt: Date
}

/// One in-flight (or just-failed) download, kept only in memory - its
/// state is rebuilt from the live `URLSessionTask` on relaunch, not
/// persisted separately.
@MainActor
@Observable
final class ActiveDownload: Identifiable {
    enum Phase {
        case downloading(bytesWritten: Int64, totalBytes: Int64?)
        case failed(message: String, resumeData: Data?)
    }

    /// `URLSessionTask.taskIdentifier` - stable across a relaunch for the
    /// same background task, so this doubles as the task's own identity.
    let id: Int
    let remoteURL: URL
    let bundleID: String
    let appName: String
    let version: String
    let sourceLabel: String
    let suggestedFileName: String
    var phase: Phase

    /// Smoothed transfer rate, in bytes/second, while `phase` is
    /// `.downloading`. `nil` until there have been at least two samples far
    /// enough apart to measure - meaningless otherwise.
    private(set) var bytesPerSecond: Double?
    private var lastSampleTime: Date?
    private var lastSampleBytes: Int64 = 0

    init(
        id: Int,
        remoteURL: URL,
        bundleID: String,
        appName: String,
        version: String,
        sourceLabel: String,
        suggestedFileName: String,
        phase: Phase
    ) {
        self.id = id
        self.remoteURL = remoteURL
        self.bundleID = bundleID
        self.appName = appName
        self.version = version
        self.sourceLabel = sourceLabel
        self.suggestedFileName = suggestedFileName
        self.phase = phase
    }

    /// Updates progress and re-estimates throughput. Samples are only taken
    /// at most 5x/second (`didWriteData` fires far more often than that on
    /// a fast connection) and blended with the previous estimate with a
    /// simple exponential moving average, so the displayed rate doesn't
    /// jitter between consecutive chunks of wildly different size.
    func updateProgress(bytesWritten: Int64, totalBytes: Int64?) {
        let now = Date()
        if let lastSampleTime {
            let elapsed = now.timeIntervalSince(lastSampleTime)
            if elapsed >= 0.2 {
                let instantaneous = Double(bytesWritten - lastSampleBytes) / elapsed
                bytesPerSecond = bytesPerSecond.map { $0 * 0.7 + instantaneous * 0.3 } ?? instantaneous
                self.lastSampleTime = now
                lastSampleBytes = bytesWritten
            }
        } else {
            lastSampleTime = now
            lastSampleBytes = bytesWritten
        }
        phase = .downloading(bytesWritten: bytesWritten, totalBytes: totalBytes)
    }
}

/// Formats a bytes/second figure the same way everywhere it's shown
/// (`DownloadsView`, `DownloadLinkRow`) - e.g. "3.1 MB/s".
func formattedTransferRate(_ bytesPerSecond: Double) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file) + "/s"
}
