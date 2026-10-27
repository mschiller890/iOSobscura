import Foundation
import Observation
import ObscuraCore

/// Drives real, in-app downloads of the `.ipa` mirrors
/// `/getAppVersionLinks/{bundleID}/{version}` lists, using a **background**
/// `URLSession` so a download keeps running while the app is suspended and
/// reattaches correctly if the app is relaunched (including after being
/// killed by the system) while one is still in flight.
///
/// The key to that reattachment: a background session is recreated with the
/// same identifier exactly once, eagerly, at app launch (`start()`, called
/// from `AppDelegate.didFinishLaunching`) - the OS then hands back the same
/// `URLSessionTask` objects (same `taskIdentifier`) for anything still
/// running. Since nothing else about a relaunched process survives, every
/// fact needed to rebuild an `ActiveDownload` (app name, version, final
/// filename, the mirror's label) is stashed as JSON on the task's own
/// `taskDescription` when the download is started.
@MainActor
@Observable
final class DownloadManager: NSObject {
    static let shared = DownloadManager()

    private(set) var activeDownloads: [ActiveDownload] = []
    private(set) var completedDownloads: [DownloadRecord] = []

    /// Set by `AppDelegate.application(_:handleEventsForBackgroundURLSession:completionHandler:)`;
    /// called once this session's queued delegate callbacks have all run,
    /// which is what tells iOS it can stop keeping the app alive for them.
    var backgroundCompletionHandler: (() -> Void)?

    nonisolated let downloadsDirectory: URL
    private nonisolated let recordsFileURL: URL
    private nonisolated let sessionIdentifier = "com.mschiller890.iosobscura.downloads"
    private var session: URLSession!

    private override init() {
        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        downloadsDirectory = documents.appendingPathComponent("Downloads", isDirectory: true)
        recordsFileURL = support.appendingPathComponent("downloaded-ipas.json")
        super.init()
        try? fm.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        try? fm.createDirectory(at: support, withIntermediateDirectories: true)
        loadRecords()
    }

    /// Call once, eagerly, at app launch - not lazily on first use. A
    /// background `URLSession` only reattaches to tasks that kept running
    /// while the app was away if it's recreated with the same identifier
    /// before anything asks about them.
    func start() {
        guard session == nil else { return }
        let config = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        reattachExistingTasks()
    }

    private func reattachExistingTasks() {
        session.getAllTasks { [weak self] tasks in
            guard let self else { return }
            let rebuilt: [ActiveDownload] = tasks.compactMap { task in
                guard let downloadTask = task as? URLSessionDownloadTask,
                      let info = Self.decodePendingInfo(downloadTask.taskDescription) else { return nil }
                let total = downloadTask.countOfBytesExpectedToReceive
                return ActiveDownload(
                    id: downloadTask.taskIdentifier,
                    remoteURL: info.remoteURL,
                    bundleID: info.bundleID,
                    appName: info.appName,
                    version: info.version,
                    sourceLabel: info.sourceLabel,
                    suggestedFileName: info.suggestedFileName,
                    phase: .downloading(
                        bytesWritten: max(downloadTask.countOfBytesReceived, 0),
                        totalBytes: total > 0 ? total : nil
                    )
                )
            }
            Task { @MainActor in
                for download in rebuilt where !self.activeDownloads.contains(where: { $0.id == download.id }) {
                    self.activeDownloads.append(download)
                }
            }
        }
    }

    // MARK: - Queries used by the UI

    func isDownloaded(_ link: DownloadLink) -> Bool {
        completedDownloads.contains { $0.remoteURL == link.url }
    }

    func activeDownload(for link: DownloadLink) -> ActiveDownload? {
        activeDownloads.first { $0.remoteURL == link.url }
    }

    func fileURL(for record: DownloadRecord) -> URL {
        downloadsDirectory.appendingPathComponent(record.fileName)
    }

    // MARK: - Starting, retrying, cancelling

    func start(link: DownloadLink, bundleID: String, appName: String, version: String) {
        guard activeDownload(for: link) == nil, !isDownloaded(link) else { return }
        DownloadNotifications.requestAuthorizationIfNeeded()
        let info = PendingDownloadInfo(
            bundleID: bundleID,
            appName: appName,
            version: version,
            sourceLabel: link.source ?? link.rawLabel,
            suggestedFileName: suggestedFileName(appName: appName, version: version, url: link.url),
            remoteURL: link.url
        )
        enqueue(task: session.downloadTask(with: link.url), info: info)
    }

    func retry(_ download: ActiveDownload) {
        guard case .failed(_, let resumeData) = download.phase else { return }
        activeDownloads.removeAll { $0.id == download.id }
        let info = PendingDownloadInfo(
            bundleID: download.bundleID,
            appName: download.appName,
            version: download.version,
            sourceLabel: download.sourceLabel,
            suggestedFileName: download.suggestedFileName,
            remoteURL: download.remoteURL
        )
        let task = resumeData.map { session.downloadTask(withResumeData: $0) } ?? session.downloadTask(with: download.remoteURL)
        enqueue(task: task, info: info)
    }

    private func enqueue(task: URLSessionDownloadTask, info: PendingDownloadInfo) {
        task.taskDescription = Self.encodePendingInfo(info)
        activeDownloads.append(ActiveDownload(
            id: task.taskIdentifier,
            remoteURL: info.remoteURL,
            bundleID: info.bundleID,
            appName: info.appName,
            version: info.version,
            sourceLabel: info.sourceLabel,
            suggestedFileName: info.suggestedFileName,
            phase: .downloading(bytesWritten: 0, totalBytes: nil)
        ))
        task.resume()
    }

    func cancel(_ download: ActiveDownload) {
        activeDownloads.removeAll { $0.id == download.id }
        session.getAllTasks { tasks in
            tasks.first { $0.taskIdentifier == download.id }?.cancel()
        }
    }

    func dismissFailed(_ download: ActiveDownload) {
        activeDownloads.removeAll { $0.id == download.id }
    }

    // MARK: - Completed downloads

    func delete(_ record: DownloadRecord) {
        try? FileManager.default.removeItem(at: fileURL(for: record))
        completedDownloads.removeAll { $0.id == record.id }
        saveRecords()
    }

    @MainActor
    fileprivate func markFailed(taskID: Int, message: String, resumeData: Data?) {
        guard let download = activeDownloads.first(where: { $0.id == taskID }) else { return }
        download.phase = .failed(message: message, resumeData: resumeData)
        DownloadNotifications.notifyFailed(appName: download.appName, version: download.version, message: message)
    }

    @MainActor
    fileprivate func completeDownload(taskID: Int, record: DownloadRecord) {
        activeDownloads.removeAll { $0.id == taskID }
        completedDownloads.insert(record, at: 0)
        saveRecords()
        DownloadNotifications.notifyFinished(appName: record.appName, version: record.version)
    }

    // MARK: - Naming

    private func suggestedFileName(appName: String, version: String, url: URL) -> String {
        let base = "\(Self.sanitize(appName))-\(Self.sanitize(version))"
        let ext = url.pathExtension.isEmpty ? "ipa" : url.pathExtension
        var candidate = "\(base).\(ext)"
        var counter = 2
        while FileManager.default.fileExists(atPath: downloadsDirectory.appendingPathComponent(candidate).path) {
            candidate = "\(base)-\(counter).\(ext)"
            counter += 1
        }
        return candidate
    }

    private nonisolated static func sanitize(_ string: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let mapped = String(string.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        let collapsed = mapped.replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    // MARK: - taskDescription <-> PendingDownloadInfo

    private nonisolated static func encodePendingInfo(_ info: PendingDownloadInfo) -> String? {
        guard let data = try? JSONEncoder().encode(info) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private nonisolated static func decodePendingInfo(_ string: String?) -> PendingDownloadInfo? {
        guard let string, let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PendingDownloadInfo.self, from: data)
    }

    // MARK: - Persistence of completed records (the bytes live separately, as files)

    private func loadRecords() {
        guard let data = try? Data(contentsOf: recordsFileURL) else { return }
        var records = (try? JSONDecoder().decode([DownloadRecord].self, from: data)) ?? []
        // A record whose file is gone (deleted via the Files app, say) shouldn't linger.
        records.removeAll { !FileManager.default.fileExists(atPath: downloadsDirectory.appendingPathComponent($0.fileName).path) }
        completedDownloads = records
    }

    private func saveRecords() {
        guard let data = try? JSONEncoder().encode(completedDownloads) else { return }
        try? data.write(to: recordsFileURL, options: .atomic)
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let id = downloadTask.taskIdentifier
        let total: Int64? = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
        Task { @MainActor in
            guard let download = self.activeDownloads.first(where: { $0.id == id }) else { return }
            download.updateProgress(bytesWritten: totalBytesWritten, totalBytes: total)
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let id = downloadTask.taskIdentifier
        guard let info = Self.decodePendingInfo(downloadTask.taskDescription) else { return }

        let destination = downloadsDirectory.appendingPathComponent(info.suggestedFileName)
        let fm = FileManager.default
        try? fm.removeItem(at: destination)

        do {
            try fm.moveItem(at: location, to: destination)
            // Re-downloadable content shouldn't eat into the user's iCloud backup.
            var excluded = URLResourceValues()
            excluded.isExcludedFromBackup = true
            var mutableDestination = destination
            try? mutableDestination.setResourceValues(excluded)

            let size = (try? fm.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? nil
            let record = DownloadRecord(
                id: UUID(),
                bundleID: info.bundleID,
                appName: info.appName,
                version: info.version,
                sourceLabel: info.sourceLabel,
                remoteURL: info.remoteURL,
                fileName: info.suggestedFileName,
                fileSizeBytes: size,
                completedAt: Date()
            )
            Task { @MainActor in self.completeDownload(taskID: id, record: record) }
        } catch {
            let message = "Couldn't save the file: \(error.localizedDescription)"
            Task { @MainActor in self.markFailed(taskID: id, message: message, resumeData: nil) }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return } // already removed by cancel(_:)
        let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        let id = task.taskIdentifier
        let message = error.localizedDescription
        Task { @MainActor in self.markFailed(taskID: id, message: message, resumeData: resumeData) }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
