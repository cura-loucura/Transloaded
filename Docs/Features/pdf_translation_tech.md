# PDF & Image Translation Support - Technical Reference

## Overview

Adding PDF and image support to Transloaded would allow users to open PDFs and image files (e.g., book page scans), extract their text content into the "original" panel, translate it, and optionally preview the source document side-by-side.

## Text Extraction

Apple's **PDFKit** framework (`PDFDocument`, `PDFPage`) can extract text natively with no third-party dependencies. Text is accessed via `page.string` on each page.

Extraction quality varies by PDF type:

- **Digitally authored PDFs** (from Word, LaTeX, web export) — text extracts cleanly
- **Scanned PDFs** (photographed documents) — no text layer, extraction returns nothing
- **Mixed PDFs** — unpredictable results

For scanned PDFs, Apple's **Vision** framework (`VNRecognizeTextRequest`) provides on-device OCR with multi-language support. This is a significant step up in complexity.

## PDF Preview Panel

PDFKit provides `PDFView`, an AppKit view that renders PDFs with scrolling, zoom, and page navigation built in. It can be wrapped in `NSViewRepresentable` for SwiftUI integration.

## Architecture Impact

### FileSystemService
Extend file type detection to accept `.pdf` UTI types, routed through a separate loading path from plain text files.

### OpenFile Model
Would need to hold either raw text or a `PDFDocument` reference, plus extracted text as a separate property for translation.

### FileContentView
Branch between the current `Text`/`TextEditor` display and a `PDFView` wrapper based on file type.

### Translation Panels
No changes needed. Panels already work with plain strings, and extracted PDF text is just a string.

### New: PDF Preview Panel
A separate panel type alongside translation panels, showing the rendered PDF via `PDFView`.

## Tradeoffs

| Aspect | Simple (PDFKit only) | Full (PDFKit + Vision OCR) |
|---|---|---|
| Text PDFs | Works well | Works well |
| Scanned PDFs | Silent failure (empty text) | Works, but slower |
| Layout fidelity | Paragraphs may merge, columns may interleave | Same issue |
| Dependencies | PDFKit (built-in) | PDFKit + Vision (both built-in) |
| Sandbox impact | None — same file access entitlements | None |
| Complexity | Moderate — mainly UI branching | Significant — async OCR pipeline per page |

## Layout Reconstruction Challenge

PDFs don't store "paragraphs" — they store positioned glyphs. Multi-column layouts, tables, footnotes, and headers all come out as a jumbled stream of text. There is no perfect solution for this, even with paid libraries. This is the biggest challenge in PDF text extraction.

## Recommended Approach

Start with PDFKit-only extraction:

1. Show extracted text in the original panel
2. Show rendered PDF in a preview panel
3. Translate the extracted text using existing translation infrastructure
4. Display a visible note when extraction yields little or no text ("This PDF may be scanned — text extraction is limited")

Vision OCR can be layered in later as a second pass for scanned documents.

---

## Image OCR Support

### Overview

Apple's **Vision** framework (`VNRecognizeTextRequest`) performs on-device OCR on images — the same technology behind Live Text in Photos and Preview. This enables opening folders of book page images and extracting translatable text from them.

### Supported Formats

Any format `CGImage` can load: PNG, JPEG, TIFF, HEIC, BMP.

### Recognition Options

- `.accurate` — slower, higher quality (recommended for book pages)
- `.fast` — quicker, rougher results (useful for quick previews)

### Language Support

Vision OCR recognizes 18 languages, largely overlapping with Transloaded's existing translation languages.

### How It Fits Transloaded

The workflow is nearly identical to the scanned-PDF OCR path — the same Vision pipeline, with the only difference being the input source (`CGImage` from an image file instead of a rendered PDF page).

- A folder of book page images loads in the sidebar like any other directory
- Clicking an image runs OCR and shows extracted text in the original panel
- Translation works on the extracted text string as usual
- A preview panel shows the source image (simple SwiftUI `Image` view — no `NSViewRepresentable` needed)

### Architecture Impact

#### FileSystemService
Extend file type detection to accept image UTI types (`.png`, `.jpeg`, `.tiff`, `.heic`, `.bmp`), routed through a Vision OCR loading path.

#### OpenFile Model
Same approach as PDF — hold the extracted text as a string property, plus a reference to the source image for preview.

#### FileContentView
Add a third branch for image files, displaying the source image in a scrollable/zoomable view.

#### Translation Panels
No changes needed — extracted text is a plain string.

### Shared OCR Pipeline

If Vision OCR is built for scanned PDFs, image support comes almost for free. The OCR logic is shared — the only new work is detecting image files and loading them as `CGImage` instead of rendering PDF pages.

### Recommended Approach

1. Build Vision OCR for scanned PDFs first
2. Extract the OCR pipeline into a shared service (e.g., `OCRService`)
3. Add image file detection to `FileSystemService`
4. Route image files through the same `OCRService`
5. Show source image in a preview panel using a SwiftUI `Image` view
6. Display confidence or warning when OCR quality is low

---

## Continuity Camera — Import from iPhone

### Overview

Apple's **Continuity Camera** API allows a Mac app to trigger the iPhone camera directly and receive captured images. This is the same system behind "Import from iPhone" in Finder and Pages. It enables a workflow where users photograph book pages with their iPhone and the images land directly in Transloaded, ready for OCR and translation.

### Two Capture Modes

- **Take Photo** — Opens the iPhone camera, snaps a single photo, delivers it to the Mac app as an `NSImage`
- **Scan Documents** — Opens the iPhone's document scanner with auto-edge-detection, perspective correction, contrast enhancement, and multi-page support. Delivers scanned pages as images. This mode is ideal for book pages as it significantly improves downstream OCR accuracy.

### Native Integration

Continuity Camera is accessed through `NSServicesMenuRequestor` on the view that receives the image. macOS handles all iPhone communication (Handoff, Bluetooth, Wi-Fi) transparently — the app never talks to the iPhone directly. The captured images arrive as `NSImage` objects.

### Requirements

- Both devices signed into the same Apple ID
- Bluetooth and Wi-Fi enabled on both
- iPhone running iOS 16+ and Mac running macOS 13+
- Devices must be near each other

All requirements are covered since Transloaded already targets macOS 15.

### How It Would Fit Transloaded

1. User opens a folder in the sidebar
2. Clicks "Import from Camera" (toolbar button or context menu)
3. iPhone camera activates — user photographs book pages
4. Images are saved to the active folder automatically
5. Sidebar updates via the existing `FileWatcherService`
6. Clicking the new image runs Vision OCR and shows extracted text for translation

### Architecture Impact

- **Toolbar / Context Menu** — Add an "Import from Camera" action when a folder is selected
- **NSServicesMenuRequestor** — Register the appropriate view as a Continuity Camera receiver
- **File Saving** — Save incoming `NSImage` to the active folder with a sequential naming scheme (e.g., `scan_001.heic`)
- **FileWatcherService** — Already monitors folders for changes, so new images appear in the sidebar automatically
- **OCR + Translation** — Uses the same shared `OCRService` pipeline from the image/PDF support

### Why This Works Well

Most of the complexity is handled by Apple. The app only needs to register as a Continuity Camera receiver and save the incoming `NSImage`. The OCR, translation, file watching, and sidebar management all use infrastructure that already exists or would be built as part of PDF/image support.

---

## Implementation Roadmap

All three features build on each other naturally:

1. **PDF text extraction** (PDFKit) — foundation layer, moderate effort
2. **Vision OCR** (scanned PDFs + images) — shared pipeline, significant effort
3. **Continuity Camera** (iPhone import) — lightweight integration on top of existing OCR and file watching

Each layer is independently useful and shippable. The OCR pipeline is the core investment that unlocks both image support and the full Continuity Camera workflow.
