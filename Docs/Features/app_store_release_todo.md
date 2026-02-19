# App Store Release TODO

## Blockers — Required for Submission

- [ ] **Code Signing for Distribution** — Change `CODE_SIGN_IDENTITY` from `"Apple Development"` to `"Apple Distribution"` for the Release configuration in `project.yml`. Create an App Store Distribution Certificate in Xcode → Settings → Accounts, and create a Mac App Store provisioning profile for `com.transloaded.app`.

- [ ] **App Store Connect Setup** — Create a new macOS app at appstoreconnect.apple.com with bundle ID `com.transloaded.app`. Set price to €1.99 (Tier 2). Fill in: app name, subtitle, description, keywords, support URL, and category (Productivity).

- [ ] **Privacy Policy URL** — Create a publicly hosted page (GitHub Gist, Notion, or simple site) stating that all translation runs on-device and no data is collected. A URL is mandatory — Apple will reject without one.

- [ ] **Screenshots** — Take screenshots from the app running on macOS. The Mac App Store requires:
  - 1280 × 800 (required)
  - 2560 × 1600 (required for Retina displays)

- [ ] **Archive & Upload** — In Xcode: Product → Archive → Distribute App → App Store Connect → Upload.

- [ ] **App Store Connect Review Submission** — After upload, go to App Store Connect, attach the build, fill in all metadata, and hit Submit for Review. Review typically takes 1–3 business days for Mac apps.

## Strongly Recommended

- [ ] **Create New App Icon** — Design a brand new logo and export it as a proper icon set. The App Store requires a **1024 × 1024 PNG** (no transparency, no rounded corners — Apple applies the mask). Export the following sizes for `Assets.xcassets/AppIcon.appiconset/`:
  - 16 × 16
  - 32 × 32
  - 64 × 64
  - 128 × 128
  - 256 × 256
  - 512 × 512
  - 1024 × 1024 (App Store submission)
  - Also provide @2x variants (32, 64, 256, 512) for Retina displays.
  Tools like Sketch, Figma, or Pixelmator Pro can export all sizes at once from a single vector source.

- [ ] **Verify App Sandbox Entitlements** — The Mac App Store requires App Sandbox to be enabled. Run the app and check Console.app for any sandbox violations before submitting. Current `Transloaded/Transloaded.entitlements` is minimal — keep it that way and only add entitlements that are genuinely needed.

- [ ] **Accessibility Pass** — Add `accessibilityLabel` and `accessibilityHint` to toolbar buttons, sidebar items, translation panels, and interactive controls. Apple review can flag missing accessibility support.

- [ ] **macOS 15+ Warning in Description** — The minimum deployment target is macOS 15.0 (Sequoia). Make this clearly visible in the App Store description so users on older macOS don't purchase and get frustrated.

## Good to Have (Can Wait for v1.1)

- [ ] **Localization** — UI strings are all hardcoded English. Consider localizing at least French, Spanish, Japanese, and Portuguese using `String(localized:)` or `.strings` files.
- [ ] **Unit Tests** — Add tests for `TranslationService` (caching, two-hop logic), `FileSystemService` (text file detection), and `SupportedLanguage` mappings.
- [ ] **Error Messages** — Review user-facing error strings for clarity. Handle edge cases like failed language pack downloads (no disk space, no network).
- [ ] **Large File Handling** — Consider a hard upper limit beyond the existing >1MB warning to prevent unresponsiveness.
- [ ] **RTL / Vertical Text** — Arabic is a supported language but RTL rendering is not implemented. Note this limitation in the App Store description.

## Submission Flow Reference

```
1. Xcode → Product → Archive
2. Organizer → Distribute App → App Store Connect → Upload
3. App Store Connect → Attach build → Fill metadata → Submit for Review
4. Apple reviews (1–3 business days for Mac)
5. App goes live (or hold for manual release)
```

## Notes

- **Bundle ID** — `com.transloaded.app` cannot be changed after the first release. Convention is `com.developername.appname` but it works as-is.
- **Version** — `MARKETING_VERSION: 1.0` and `CURRENT_PROJECT_VERSION: 1` are fine for the initial release.
- **Copyright** — Update the year/entity in `project.yml` if needed: `INFOPLIST_KEY_NSHumanReadableCopyright`.
