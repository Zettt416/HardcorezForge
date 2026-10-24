# HardcorezForge

A lightweight, high-performance, and all-in-one mobile office suite built with Flutter. HardcorezForge provides offline document creation, spreadsheet calculations, slide presentations, PDF reading, and digital signature capabilities designed specifically for modern mobile workflows.

---

## Key Features

### 1. Document Editor (Word / Docs)
- **Rich Text Formatting**: Bold, italic, underline, bullet lists, numbered lists, and header hierarchy.
- **Fast & Responsive Canvas**: Optimized mobile text-rendering with live word, character, and line counters.
- **Docx & ODT Text Extraction**: Native background extraction of modern `.docx` and OpenDocument `.odt` text content.

### 2. Spreadsheet Studio (Excel / Sheets)
- **Interactive Calculation Grid**: Smooth pan-and-zoom spreadsheet layout with dynamic row and column headers.
- **Built-in Formula Engine**: Computes cell expressions, mathematical operations (`+`, `-`, `*`, `/`), and statistical functions:
  - `=SUM(A1:A10)`
  - `=AVG(B1:B5)`
  - `=COUNT(C1:C20)`
  - `=MIN(D1:D10)`
  - `=MAX(E1:E10)`
- **CSV & XLSX Support**: Fast native parser for comma/tab-separated values and Microsoft Excel `.xlsx` shared-string structures.

### 3. Presentation Studio (PowerPoint / Slides)
- **Visual Slide Deck Builder**: Create slide outlines, edit titles, bullets, and notes effortlessly.
- **Preset Themes**: Multiple color palettes and typography treatments.
- **Fullscreen Presentation Mode**: Distraction-free presentation player with swipeable slide navigation.

### 4. PDF Reader & Digital Signature
- **Native PDF Engine**: High-fidelity PDF page rendering powered by Android's native `PdfRenderer`.
- **Digital Signature Pad**: Smooth, customizable digital signature canvas with variable stroke widths, undo, and reset.
- **Official Stamp Badges**: Pre-configured stamps (Approved, Paid, Confidential, Verified) ready to embed into documents.
- **Direct PDF Sign Flow**: Select any PDF from device memory and immediately place signatures and stamps.

### 5. Universal Device Document Scanner
- **Auto-Discovery**: Scans and aggregates office documents across device storage without manual browsing.
- **WhatsApp Multi-Account Support**: Automatically detects documents received via WhatsApp, WhatsApp Business, multi-account folders, and Telegram.
- **Storage Access**: Seamless file picking and import from external and internal storage.

---

## Tech Stack & Architecture

- **Framework**: [Flutter](https://flutter.dev) (Dart 3.x)
- **Native Android Layer**: Kotlin with `MethodChannel` for:
  - Zero-latency hardware-accelerated PDF page rendering (`PdfRenderer`).
  - Native XML parsing for `.docx` and `.xlsx` without heavy third-party SDK bloat.
  - Scoped storage permissions (`MANAGE_EXTERNAL_STORAGE` / MediaStore).
- **Design System**: Material 3 with adaptive light and dark themes.

---

## Project Structure

```text
lib/
├── core/
│   ├── models/         # Document data models and serialization
│   ├── theme/          # Color tokens, typography, and theme data
│   └── utils/          # Native platform channels and share utilities
├── data/
│   ├── device_document_scanner.dart  # Multi-directory office file scanner
│   └── document_repository.dart      # Local document persistence layer
├── features/
│   ├── home/           # Main hub, quick action cards, and document browser
│   ├── pdf_tools/      # PDF viewer and signing integration
│   ├── presentation/   # Slide presentation editor and player
│   ├── signature/      # Signature drawing canvas and stamp tool
│   ├── splash/         # Animated startup splash screen
│   ├── spreadsheet/    # Grid view, formula bar, and formula engine
│   └── word_editor/    # Rich document text editor
└── main.dart           # App entry point and theme bootstrap
```

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.19 or later recommended)
- Android SDK (API Level 21+)

### Installation & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/Zettt416/HardcorezForge.git
   cd HardcorezForge
   ```

2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

3. Run automated tests:
   ```bash
   flutter test
   ```

4. Run on a connected device:
   ```bash
   flutter run
   ```

5. Build production release APK:
   ```bash
   flutter build apk --release
   ```
   The compiled APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.
