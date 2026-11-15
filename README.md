# Readly

Readly is an e-book reader for iOS and macOS, built with SwiftUI. It reads EPUB and PDF files and helps with books in foreign languages: you can translate a selection on the spot, save phrases, and have the text read aloud.

## Features

- **Library**: import EPUB and PDF books and browse them by *All*, *Reading*, *Favorites*, custom collections and *Trash*. Cover thumbnails are generated automatically.
- **Reader**: paginated reading with a table of contents, go to location, full-text search, bookmarks and adjustable appearance (themes, fonts, layout).
- **Translation**: translate a selected passage with:
  - **Apple Translate**: on device, free, no API key needed
  - **OpenAI**
  - **Claude (Anthropic)**
  - **Google Gemini**
- **Translator & saved phrases**: a standalone quick translator, plus a list of phrases saved while reading.
- **Read aloud**: text-to-speech narration using system voices, with automatic language detection and voice selection.
- **Localized UI**: English, Polish, German, French, Spanish and Italian.

## Requirements

- Xcode 16 or newer (Swift 6)
- iOS 18.0+ / macOS 15.0+

## Getting started

```bash
git clone <repository-url>
cd Readly
open src/Readly.xcodeproj
```

Choose the `Readly` scheme, pick an iOS simulator, a device or *My Mac*, and run.

To use an LLM provider for translation, open **Settings**, pick the provider and paste your API key. Keys are stored encrypted in the app's local Application Support directory and never leave the device except in requests to the provider you picked. Apple Translate works without any setup.

## Project structure

```
src/
├── Readly/                 # App target (entry point only)
├── Readly.xcodeproj
└── Packages/ReadlyKit/     # All app code, as a local Swift package
    ├── Sources/
    │   ├── ReadlyCore/         # Core models: Publication, BookFormat, ReadingPosition
    │   ├── EPUBSupport/        # EPUB parsing (container, OPF, navigation)
    │   ├── PDFSupport/         # PDF support
    │   ├── LibraryData/        # SwiftData library: books, collections, bookmarks, phrases
    │   ├── TranslationCore/    # Translation providers, LLM client, API key storage
    │   ├── SystemTranslation/  # Apple Translation framework bridge
    │   ├── Speech/             # Text-to-speech narration
    │   ├── Preferences/        # App settings, themes, reader appearance
    │   ├── DesignSystem/       # Shared UI components
    │   ├── LibraryFeature/     # Library screens
    │   ├── ReaderFeature/      # Reader screens and web-based rendering engine
    │   ├── SettingsFeature/    # Settings screens
    │   ├── TranslatorFeature/  # Quick translator and saved phrases
    │   └── AppFeature/         # Root views, navigation, dependency wiring
    └── Tests/
```

Modules are split into a domain layer and UI features. `AppFeature` is the only product the app target imports.

### Adding a book format

Add a case to `BookFormat` in `ReadlyCore`, implement a `BookFormatHandler` for it, and register the handler in the `BookFormatRegistry` in `AppFeature/AppEnvironment.swift`.

## Running tests

From the command line:

```bash
cd src/Packages/ReadlyKit
swift test
```

Or in Xcode, open `src/Packages/ReadlyKit/Package.swift` and press ⌘U.

## Dependencies

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation): unpacks EPUB archives

## License

MIT. See [LICENSE](LICENSE).
