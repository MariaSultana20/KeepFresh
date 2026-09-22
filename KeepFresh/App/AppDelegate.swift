import FirebaseCore
import SwiftData
import UIKit

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

        // Reads GoogleService-Info.plist. Must run before any
        // FirebaseAuthService call — SceneDelegate constructs AppCoordinator
        // (and its FirebaseAuthService) synchronously right after this
        // method returns, so "configure before first use" is satisfied by
        // ordering alone; no extra guard needed at the call site.
        FirebaseApp.configure()
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
