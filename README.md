# KeepFresh

**An iOS app that tracks the shelf life of packaged products and reminds you before they expire.**

Built end-to-end in Swift/UIKit with a real Firebase authentication backend, local-first persistence via SwiftData, and scheduled local notifications — architected around MVVM-C for testability and a clean separation between UI, business logic, and data.

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![UI](https://img.shields.io/badge/UI-UIKit%20(programmatic)-blue)
![Architecture](https://img.shields.io/badge/architecture-MVVM--C-informational)

---

## Overview

KeepFresh solves a simple, everyday problem: packaged food and household products get pushed to the back of a cupboard and forgotten until they've expired. The app lets a user log what they own — name, category, quantity, purchase date, expiry date — and get a local notification before each item goes bad, with a traffic-light status system (Good / Expiring Soon / Expired) driving the UI throughout.

The project is built as a portfolio-quality reference for iOS engineering practices: no storyboards, no third-party UI kits, a protocol-first service layer that swaps real implementations in behind mocks, and a growing suite of unit tests around the pieces that carry real logic (expiry-status math, repository contracts, form validation).

## Features

- **Authentication** — Sign in with Apple, Google Sign-In, and email/password, all backed by Firebase Auth (`AuthServiceProtocol`, with `FirebaseAuthService` as the production conformer and `MockAuthService` kept for previews/tests). Sessions persist across launches; signing out requires confirmation.
- **Item tracking** — Add and edit items with name, category, quantity + unit (a closed set, not free text), purchase date, expiry date, an optional note, and a configurable reminder lead time.
- **Home dashboard** — A greeting header, three summary cards (All Items / Expired / Expiring Soon), and a live "Expiring Soon" preview of the five soonest-expiring items.
- **Items list** — Full inventory with search, a status-filter segmented control, and a category filter + sort menu.
- **Item details** — Full detail view per item, with edit and delete (delete also cancels that item's scheduled notification).
- **Local notifications** — Expiry reminders scheduled via `UNUserNotificationCenter`, with deterministic identifiers so rescheduling never leaks duplicates; the Notifications tab lists everything currently scheduled.
- **Profile** — Edit display name, sign out (with confirmation).
- **Dark Mode** — Full support via dynamic system colors, no hardcoded palette.

## Tech stack

| Layer | Choice |
|---|---|
| Language | Swift 5.9 |
| UI | UIKit, 100% programmatic (no Storyboards/XIBs) |
| Architecture | MVVM-C (Model–View–ViewModel–Coordinator — ViewModels hold presentation logic and are unit-testable in isolation; Coordinators own navigation so view controllers don't push/present each other directly) |
| Persistence | SwiftData (local-only for v1) |
| Auth | Firebase Auth + GoogleSignIn-iOS SDK (Apple / Google / email-password) |
| Notifications | `UserNotifications` (local, on-device scheduling) |
| Testing | XCTest — 30+ unit tests across expiry-status logic, the repository contract, and item-editor validation |
| Minimum target | iOS 17.0 |

## Architecture notes

Every cross-cutting concern is defined as a protocol and injected, not reached for as a singleton:

- `AuthServiceProtocol` → `FirebaseAuthService` (production) / `MockAuthService` (tests, previews)
- `ItemRepository` → `SwiftDataItemRepository` (production) / `InMemoryItemRepository` (tests)
- `NotificationServiceProtocol` → `LocalNotificationService` (production) / `InMemoryNotificationService` (tests)

This keeps the ViewModel and view-controller layers free of Firebase/SwiftData imports, and means the whole app can run — and be tested — against fakes with zero network or disk dependency.

## Project structure

```
KeepFresh/
  App/          AppDelegate, SceneDelegate, AppCoordinator, AppTheme
  Features/     Auth, Home, Items, AddItem, ItemEditor, ItemDetails, Notifications, Profile
  Models/       Item, ExpiryStatus, ExpiryStatusCalculator, CategoryIcon
  Services/     Auth, persistence, and notification protocols + implementations
  Shared/       Reusable views (PrimaryButton, ItemRowView, EmptyStateView, ...)
  Resources/    Assets.xcassets
KeepFreshTests/ Unit tests
```

## Getting started

1. Clone the repo and open `KeepFresh.xcodeproj` in Xcode 15+.
2. **Signing** — In *Signing & Capabilities*, select your own development team (automatic signing is already configured; bundle ID is `com.maria.keepfresh`).
3. **Sign in with Apple** — Enable the *Sign in with Apple* capability on your App ID in the Apple Developer portal; the entitlement is already requested in `KeepFresh.entitlements`, but Xcode can't provision it until it's enabled on the App ID.
4. **Firebase** — Add your own `GoogleService-Info.plist` to the project root (this file is gitignored on purpose — never commit real Firebase credentials).
5. Build and run on an iOS 17+ simulator or device.

## Running tests

```
Cmd+U in Xcode
```
or
```
xcodebuild test -project KeepFresh.xcodeproj -scheme KeepFresh -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Roadmap

- Account deletion (local data + Firebase user)
- Persisted notification history (read/unread, clear history)
- Profile display-name propagation to Home's greeting (needs an app-wide session observable)
- Accessibility and Dark Mode audit
- Optional Firestore/Storage sync for multi-device support
- TestFlight release

## Author

Built by [Maria Sultana](https://github.com/MariaSultana20).
