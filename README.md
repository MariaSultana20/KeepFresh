# KeepFresh (iOS)

Expiry tracker app. UIKit, programmatic UI, MVVM-C. See the "KeepFresh — Confirmed Decisions & Commit-by-Commit Build Plan" doc in the KeepFresh Claude project for the full plan and the reasoning behind the current architecture choices.

## Current state

Welcome screen (Sign in with Apple / Google / Email) and an empty-state Home screen. Authentication is backed by `MockAuthService` — there's no real backend wired up yet; any sign-in attempt succeeds after a short simulated delay so the rest of the app is testable end to end. Real auth (Firebase or equivalent) replaces it behind `AuthServiceProtocol` in a later commit.

## First-time setup in Xcode

1. Open `KeepFresh.xcodeproj`.
2. Signing & Capabilities → select your own Team (Automatic signing is already configured; bundle ID is `com.maria.keepfresh`).
3. In your Apple Developer account, enable the **Sign in with Apple** capability for this App ID — the project already requests it via `KeepFresh.entitlements`, but Xcode can't provision it until it's enabled on the App ID itself.
4. Build and run on a simulator or device running iOS 17+.

## Scope notes

- v1 is local-only (SwiftData) once persistence lands — no Firestore/Storage until there's an actual need for multi-device sync.
- No third-party dependencies yet (no CocoaPods/SPM packages) — kept out until the commit that actually needs Google Sign-In's SDK.
