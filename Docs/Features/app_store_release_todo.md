# App Store Release TODO

## Must-Do for App Store Review

- [ ] **Code Signing & Provisioning** — Update from ad-hoc signing (`"-"`) to proper Apple Developer signing with Team ID and provisioning profile.
- [ ] **App Store Metadata** — Prepare screenshots (multiple resolutions), privacy policy URL, app description, keywords, and category.
- [ ] **Privacy Policy** — Create a privacy policy URL stating no data is collected (Translation runs on-device).
- [ ] **Version & Build Numbers** — `MARKETING_VERSION: 1.0` and `CURRENT_PROJECT_VERSION: 1` are fine for initial release. Establish a versioning strategy going forward.
- [ ] **Copyright** — Update copyright year/entity from `"Copyright 2025 Transloaded"`.

## Strongly Recommended

- [ ] **Accessibility** — Add `accessibilityLabel`, `accessibilityHint`, and VoiceOver support to toolbar buttons, sidebar items, translation panels, and interactive controls.
- [ ] **App Icon** — Create resolution-specific icons or a high-res 1024x1024 source. Current icon is a single 1804-byte PNG reused at all sizes. App Store requires 1024x1024.
- [ ] **Remove Development Artifacts** — Clean up or `.gitignore` files like `Transloaded.app.zip`, `translation_tech.md`, `transloaded_implementation.md`, `transloaded_plans.md`, `wishlist.md`.

## Good to Have

- [ ] **Localization** — UI strings are all hardcoded English. Consider localizing at least French, Spanish, Japanese, Portuguese using `String(localized:)` or `.strings` files.
- [ ] **Testing** — Add unit tests for `TranslationService` (caching, two-hop logic), `FileSystemService` (text file detection), and `SupportedLanguage` mappings.
- [ ] **Error Messages** — Review user-facing error strings for clarity. Handle edge cases like failed language pack downloads (no disk space, no network).
- [ ] **Onboarding / First-Run Experience** — Add a brief first-launch tip or welcome state for new users landing in an empty editor.
- [ ] **Keyboard Shortcuts** — Verify all shortcuts are discoverable through the menu bar.
- [ ] **Sandbox Entitlements** — Current entitlements are clean and minimal. Don't add unnecessary ones.
- [ ] **Large File Handling** — Consider a hard upper limit beyond the existing >1MB warning to prevent unresponsiveness.

## Minor Polish

- [ ] **Bundle ID** — `com.transloaded.app` works but Apple convention is `com.developername.appname`. Cannot be changed after release.
- [ ] **Minimum macOS Version** — macOS 15.0 (Sequoia) required due to Translation framework dependency.
- [ ] **RTL / Vertical Text** — Arabic is a supported language but RTL text support is not implemented yet.
