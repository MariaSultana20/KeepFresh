import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // TODO: configure Firebase here (`FirebaseApp.configure()`) once
        // FirebaseAuthService replaces MockAuthService — see the build plan's
        // "wire up authentication" commit. Nothing to configure yet since v1
        // starts local-only (SwiftData) with no Firestore/Storage.
        true
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
