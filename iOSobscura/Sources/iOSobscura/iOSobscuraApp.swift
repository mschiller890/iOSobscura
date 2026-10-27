import SwiftUI
import UIKit
import UserNotifications

/// A background `URLSession` only reattaches to tasks that kept running
/// while the app was away if it's recreated, with the same identifier,
/// before anything else runs - so `DownloadManager.start()` happens here,
/// eagerly, rather than lazily from whichever view happens to need it
/// first. `handleEventsForBackgroundURLSession` is how iOS wakes (or
/// relaunches) the app when that session has events queued up; the
/// completion handler it hands over must be called once the session's
/// delegate has actually processed them; see
/// `DownloadManager.urlSessionDidFinishEvents`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        DownloadManager.shared.start()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        DownloadManager.shared.backgroundCompletionHandler = completionHandler
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Without this, a notification posted while the app is in the
    /// foreground is silently swallowed - the default is to show nothing,
    /// which is wrong here: being in the app at all doesn't mean the
    /// Downloads tab is the one on screen. `nonisolated` because this
    /// delegate protocol calls back on an arbitrary thread, and the
    /// implementation touches no actor-isolated state anyway.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}

@main
struct iOSobscuraApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
