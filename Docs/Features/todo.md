# Transloaded — TODO

## In Focus

### 1. Download Language Packs in Settings ✅
- [x] Add "Download Language Packs" section on top of the Languages tab in Settings
- [x] Show two download buttons when 2+ languages are selected:
  - `[DefaultLang] → N-1 languages` — downloads pairs from reference language to each other selected language
  - `All N language combinations` — downloads all ordered source→target pairs
- [x] Compute and display pair counts dynamically based on selection
- [x] If 4+ languages selected, show confirmation dialog: "This will download large files and may take a while."
- [x] Implement download logic via Apple Translation framework (`LanguagePackDownloadViewModel`)
- [x] Show download progress spinner with "Downloading: X → Y… (N of M)" label
- [x] Disable buttons when fewer than 2 languages are selected or download in progress
- [x] Cancel button during download
- [x] "All packs already downloaded" message when nothing to download
- [x] Error handling for failed downloads

### 2. Font Size Control (`Cmd +/-`) ✅
- [x] Add `Cmd +` / `Cmd -` keyboard shortcuts to increase/decrease font size in text panels
- [x] Add `Cmd 0` to reset to default font size
- [x] Apply to both Original and Translation panels
- [x] Wire shortcuts through the menu bar (View menu) for discoverability
- [x] Persist font size preference across sessions (UserDefaults)

### 3. File Management (Default Folder & Tree) ✅
- [x] Default folder setting in Settings > General (`~/Documents/Transloaded`)
- [x] Default folder always shown at top of sidebar, tracking changes
- [x] "New Folder" button in file tree with validation dialog
- [x] Import-to-folder dialog when a folder is selected during file import
- [x] Continuity Camera imports go to selected folder (or default folder if none)


---

## Completed

### 6. File/Directory Refresh on External Changes ✅
- [x] Watch file system for changes (FSEvents / DispatchSource)
- [x] Auto-refresh sidebar tree when files are added, removed, or renamed externally

### 4. Tutorial / Onboarding ✅
- [x] Multi-step first-run dialog (6 pages), also accessible via Help menu
- [x] Placeholder images per page (to be replaced later)
- [x] Track first-launch state so it only auto-shows once
- [x] Page content as specified in `file_management_and_tutorial_and_downloads.md`

---

## Pending

### 5. RTL & Vertical Text
- [ ] Add per-panel option for RTL text direction
- [ ] Add per-panel option for vertical text layout
- [ ] Apply to both Original and Translation panels

### 7. Accessibility & Label Translation
- [ ] Add `accessibilityLabel` / `accessibilityHint` to toolbar buttons, sidebar items, panels
- [ ] VoiceOver support for all interactive controls
- [ ] Localize UI strings (at minimum: English, Portuguese, Spanish, French, Japanese)

### 8. App Store Release
- [ ] Code signing & provisioning (Apple Developer account)
- [ ] App icon 1024x1024
- [ ] Screenshots, description, keywords, privacy policy
- [ ] Versioning strategy
- [ ] Remove dev artifacts / clean up `.gitignore`
- [ ] See `app_store_release_todo.md` for full checklist

### 9. Homebrew Support
- [ ] Create Homebrew Cask formula
- [ ] Publish and document installation via `brew install --cask transloaded`

### 10. transloaded.app Website
- [ ] Design and build a landing page
- [ ] Host and link from App Store listing / README
