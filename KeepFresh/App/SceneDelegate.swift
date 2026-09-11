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
        let coordinator = AppCoordinator(window: window, itemRepository: itemRepository)
        appCoordinator = coordinator
        coordinator.start()
    }
}
