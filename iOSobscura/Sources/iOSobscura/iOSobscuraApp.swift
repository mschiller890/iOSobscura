import SwiftUI
import UIKit

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

@main
struct iOSobscuraApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
