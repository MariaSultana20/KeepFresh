import UIKit

/// Owns the auth flow's navigation: Sign In, and the pushed Create Account
/// screen. Screens never push one another directly.
@MainActor
final class AuthCoordinator {

    var onAuthenticated: ((AuthUser) -> Void)?

    private let navigationController: UINavigationController
    private let authService: AuthServiceProtocol
    private let signInViewModel: AuthViewModel

    init(navigationController: UINavigationController, authService: AuthServiceProtocol) {
        self.navigationController = navigationController
        self.authService = authService
        self.signInViewModel = AuthViewModel(authService: authService)
    }

    func start() {
        signInViewModel.onAuthenticated = { [weak self] user in
            self?.onAuthenticated?(user)
        }
        let signInViewController = SignInViewController(viewModel: signInViewModel)
        signInViewController.onCreateAccountTapped = { [weak self] in
            self?.showCreateAccount()
        }
        navigationController.setViewControllers([signInViewController], animated: false)
    }

    private func showCreateAccount() {
        let createAccountViewModel = AuthViewModel(authService: authService)
        createAccountViewModel.onAuthenticated = { [weak self] user in
            self?.onAuthenticated?(user)
        }
        let createAccountViewController = CreateAccountViewController(viewModel: createAccountViewModel)
        navigationController.setNavigationBarHidden(false, animated: true)
        navigationController.pushViewController(createAccountViewController, animated: true)
    }
}
