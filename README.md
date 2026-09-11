# KeepFresh (iOS)

Expiry tracker app. UIKit, programmatic UI, MVVM-C. See the "KeepFresh — Confirmed Decisions & Commit-by-Commit Build Plan" doc in the KeepFresh Claude project for the full plan and the reasoning behind the current architecture choices.

## Current state

Through build-plan commit 5 (five-tab shell): Sign In / Create Account screens, then a five-tab `UITabBarController` shell (Home, Items, Add Item, Notifications, Profile). Home, Items, and Notifications each show a real empty state; Add Item's tab is intercepted and presents a modal placeholder instead of becoming the active tab; Profile shows the signed-in user's info and Sign Out.

Authentication is backed by `MockAuthService` — there's no real backend wired up yet; any sign-in attempt succeeds after a short simulated delay so the rest of the app is testable end to end. Real auth (Firebase or equivalent) replaces it behind `AuthServiceProtocol` in a later commit.

Persistence is real but not yet consumed by any screen: `Item`/`ExpiryStatus`/`ExpiryStatusCalculator` are modeled and unit-tested, and both a SwiftData-backed `ItemRepository` (the app's actual store, built from `AppDelegate`'s `ModelContainer`) and an in-memory fake (for tests/previews) exist behind the same protocol. Wiring Home's summary cards and a real Items list against it is build-plan commit 6.

Run `xcodebuild test` (or Cmd+U in Xcode) against the `KeepFreshTests` target to run the existing unit tests — this environment has no Xcode/xcodebuild available, so every commit here has only been validated by hand (structural `project.pbxproj` checks, brace-balance checks, and manual read-through); a real build in Xcode is still the first thing to do after pulling these commits.

## First-time setup in Xcode

1. Open `KeepFresh.xcodeproj`.
2. Signing & Capabilities → select your own Team (Automatic signing is already configured; bundle ID is `com.maria.keepfresh`).
3. In your Apple Developer account, enable the **Sign in with Apple** capability for this App ID — the project already requests it via `KeepFresh.entitlements`, but Xcode can't provision it until it's enabled on the App ID itself.
4. Build and run on a simulator or device running iOS 17+.

## Scope notes

- v1 is local-only (SwiftData) — no Firestore/Storage until there's an actual need for multi-device sync.
- No third-party dependencies yet (no CocoaPods/SPM packages) — kept out until the commit that actually needs Google Sign-In's SDK.
