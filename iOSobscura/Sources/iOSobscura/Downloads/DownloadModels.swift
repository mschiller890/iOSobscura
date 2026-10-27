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
}
