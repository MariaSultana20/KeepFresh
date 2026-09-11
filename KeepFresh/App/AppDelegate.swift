import UIKit
import SwiftData

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    /// The app's single SwiftData store — "local-only v1" persistence per
    /// the Build Plan, created once here (not per-scene) so every window
    /// would see one consistent data set if this app ever supported more
    /// than one (it doesn't yet — see Info.plist's
    /// UIApplicationSupportsMultipleScenes = false).
    ///
    /// `SceneDelegate` reads this to build the `SwiftDataItemRepository`
    /// it hands to `AppCoordinator`.
    lazy var modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: ItemEntity.self)
        } catch {
            fatalError("Failed to initialize the SwiftData ModelContainer: \(error)")
        }
    }()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Force the lazy ModelContainer to initialize now rather than on
        // whenever a screen first touches it — a schema/store failure
        // should surface at launch, not deep in some later user flow.
        _ = modelContainer

        // TODO: configure Firebase here (`FirebaseApp.configure()`) once
        // FirebaseAuthService replaces MockAuthService — see the build plan's
        // "wire up authentication" commit. Nothing to configure yet since v1
        // starts local-only (SwiftData) with no Firestore/Storage.
        return true
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
