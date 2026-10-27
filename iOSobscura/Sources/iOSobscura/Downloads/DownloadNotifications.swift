import UserNotifications

/// Local notifications for a download finishing or failing - the whole
/// point of putting these in the background in the first place is that
/// the user doesn't have to keep the Downloads tab open and watch a
/// progress bar, so they need some other way to find out it's done.
enum DownloadNotifications {
    /// Asks only once, in context (the first time a download is started),
    /// rather than unconditionally at launch - `requestAuthorization`
    /// itself is a no-op if the user has already allowed or denied it.
    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    static func notifyFinished(appName: String, version: String) {
        let content = UNMutableNotificationContent()
        content.title = appName
        content.body = "Version \(version) finished downloading."
        content.sound = .default
        schedule(content)
    }

    static func notifyFailed(appName: String, version: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(appName) download failed"
        content.body = "Version \(version): \(message)"
        content.sound = .default
        schedule(content)
    }

    private static func schedule(_ content: UNMutableNotificationContent) {
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
