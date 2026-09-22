import GoogleSignIn
import SwiftData
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var appCoordinator: AppCoordinator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("SceneDelegate requires AppDelegate to own the SwiftData ModelContainer")
        }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        let itemRepository = SwiftDataItemRepository(modelContext: appDelegate.modelContainer.mainContext)
        let coordinator = AppCoordinator(
            window: window,
            itemRepository: itemRepository,
            authService: FirebaseAuthService()
        )
        appCoordinator = coordinator
        coordinator.start()
    }

    /// Completes Google Sign-In's OAuth redirect back into the app.
    /// `GIDSignIn` inspects the URL itself and returns `false` for
    /// anything it doesn't recognize, so it's safe to call unconditionally
    /// here rather than trying to pre-filter by scheme.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        GIDSignIn.sharedInstance.handle(url)
    }
}
