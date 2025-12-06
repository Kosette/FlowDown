# FlowDown Agent Guide

This file provides guidance to AI coding agents working inside this repository.

## Overview
FlowDown is a Swift-based AI/LLM client for iOS and macOS (Catalyst) with a privacy-first mindset. The workspace hosts the main app plus several Swift Package Manager frameworks (e.g. `ChatClientKit`, `Storage`, `Logger`) that power storage, editing, model integrations, and on-device MLX inference. Persistent configuration lives in the `ConfigurableKit` package.

## Environment & Tooling
- Prefer opening `FlowDown.xcworkspace` so the app and frameworks resolve together under shared schemes.
- Use Xcode 26.x (Swift 6.0 toolchain) or newer to satisfy package manifests and the Swift `Testing` library.
- Build on macOS 26 or later to ensure compatibility with the required toolchain.
- Install `xcbeautify` (`brew install xcbeautify`) and pipe build output through `xcbeautify -qq` for readable logs.
- Lean on automation in `Resources/DevKit/scripts/` (localization, archiving, licensing) instead of ad-hoc scripts.
- Use `make` for release archives; clean artifacts with `make clean` (wrapper around `Resources/DevKit/scripts/archive.all.sh`).

## Platform Requirements & Dependencies
- Target platforms reflect framework minimums: iOS 17.0+, macCatalyst 17.0+ (macOS 14+ for Catalyst helpers).
- Toolchain: Swift 6.0 (`swift-tools-version: 6.0`) and the Xcode 26 SDK line are required. MLX currently resolves to `mlx-swift` 0.21.x and `mlx-swift-examples` on `main`.
- Core SwiftPM dependencies include MLX/MLX examples, ConfigurableKit, SnapKit, SwifterSwift, MarkdownView, WCDB prebuilt binaries, ZIPFoundation, ScrubberKit, AlertController, GlyphixTextFx, ColorfulX, UIEffectKit, DpkgVersion, swift-transformers, and additional UI/tooling libraries listed in `FlowDown.xcodeproj`.
- `Storage` wraps WCDB with Markdown parsing and ZIP export; `ChatClientKit` layers MLX, EventSource, and Logger to deliver on-device and streaming chat.
- MLX GPU support is automatically detected and disabled in simulator/x86_64 builds (see `FlowDown/main.swift`).

## Project Structure
- `FlowDown.xcworkspace`: Entry point with app and frameworks.
- `FlowDown/`: Application sources divided into `Application/` (entry surfaces), `Backend/` (conversations, models, storage, security), `Interface/` (UIKit), `PlatformSupport/` (macOS/Catalyst glue), and `BundledResources/` (curated assets shipped with the app).
- `FlowDown/DerivedSources/`: Generated during builds (`BuildInfo.swift`, `CloudKitConfig.swift`). Treat as generated—schemes will overwrite changes.
- `Frameworks/`: Shared Swift packages (`ChatClientKit`, `Storage`, `RichEditor`, `RunestoneEditor`, `Logger`). Each package owns its manifest and dependency graph.
- `FlowDownUnitTests/`: App-level tests using Swift's `Testing` package (`@Test` entry points).
- `Resources/`: Shared assets, localization collateral, privacy documents, and DevKit utilities.
- `Resources/DevKit/scripts/`: Automation helpers (archiving, translation, licence scanning). Prefer extending these over new stand-alone scripts.
- `Playgrounds/`: Exploratory prototypes; do not assume production readiness.

## Build & Run Commands
- Open the workspace: `open FlowDown.xcworkspace`.
- Debug builds:
  - iOS: `xcodebuild -workspace FlowDown.xcworkspace -scheme FlowDown -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' | xcbeautify -qq`
  - macOS Catalyst: `xcodebuild -workspace FlowDown.xcworkspace -scheme FlowDown-Catalyst -configuration Debug -destination 'platform=macOS' | xcbeautify -qq`
- Release archive (both platforms):
  - `make` to archive (runs `Resources/DevKit/scripts/archive.all.sh`)
  - `make clean` to reset build artifacts
- Package-only verification: `swift build --package-path Frameworks/<Package>`
- When running CI-style builds, prefer `xcodebuild -workspace FlowDown.xcworkspace -scheme FlowDown -configuration Debug build`
- Archive script automatically commits changes and bumps version before building; ensure the working tree is clean beforehand.
- Run unit tests (auto-discovers `FlowDownUnitTests`): `xcodebuild -workspace FlowDown.xcworkspace -scheme FlowDown -configuration Debug test | xcbeautify -qq`
- Localization validation helpers:
  - `python3 Resources/DevKit/scripts/check_translations.py FlowDown/Resources/Localizable.xcstrings`
  - `python3 Resources/DevKit/scripts/check_untranslated.py FlowDown/Resources/Localizable.xcstrings`
  - `python3 Resources/DevKit/scripts/update_missing_i18n.py FlowDown/Resources/Localizable.xcstrings` to scaffold missing locales; extend `NEW_STRINGS` in that script when adding new keys.

## Development Guidelines
### Swift Style
- 4-space indentation with opening braces on the same line
- Single spaces around operators and after commas
- PascalCase types; camelCase properties, methods, and file names
- Organize extensions into targeted files (`Type+Feature.swift`) and keep each file focused on one responsibility
- Lean on modern Swift patterns: `@Observable`, structured concurrency (`async`/`await`), result builders, and protocol-oriented design

### Architecture & Key Services
- Respect the established managers: `ModelManager`, `ModelToolsManager`, `ConversationManager`, `MCPService`, and `UpdateManager`. Consult them before adding new singletons.
- Compose features via dependency injection and protocols instead of inheritance.
- Keep Catalyst-specific behaviour under `PlatformSupport/` to avoid leaking platform checks throughout the codebase.
- Security hardening lives in `FlowDown/Backend/Security/`: release builds validate app signatures, strip debuggers, and verify sandbox enforcement (see `main.swift`).
- Backend services are organized by domain: `ChatTemplate`, `Conversation`, `Model`, `ModelTools`, `MCPService`, `Storage`, `Security`, `UpdateManager`.
- `main.swift` wires storage (`Storage.db()`), CloudKit sync, logging, and shared singletons (`ModelManager`, `ModelToolsManager`, `ConversationManager`, `MCPService`, `UpdateManager`, `ChatSelection`). Keep this order intact to avoid race conditions.
- `ConfigurableKit` powers persisted user settings—add keys through dedicated `Value+*.swift` helpers and publish updates via its typed publishers.

## Testing Expectations
- Add or update unit/UI tests alongside behavioural changes. `FlowDownUnitTests` leverages the Swift `Testing` library—author tests as `@Test func featureScenario_expectation()`.
- Expand coverage inside Swift packages via their `Tests/` targets (`swift test --package-path Frameworks/<Package>`).
- Run app-level tests with `xcodebuild -workspace FlowDown.xcworkspace -scheme FlowDown -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' test | xcbeautify -qq`.
- Document manual verification steps whenever UI or integration flows lack automation.

## Security & Privacy
- Never hardcode secrets; rely on user-supplied keys and platform keychains.
- Validate new managers or services against the sanctioned singleton list above.
- Use `assert`/`precondition` to capture invariants during development.
- Audit persistence changes for privacy impacts before shipping.
- Preserve existing safeguards in `main.swift`: release builds disable stdout/stderr, strip debuggers, enforce signature validation, and ensure Catalyst sandboxing.
- Keep CloudKit identifiers, entitlements, and derived `CloudKitConfig.swift` generation in sync with deployment environments.

## Documentation & Knowledge Sharing
- Capture key findings from external research in PR descriptions so future contributors can trace decisions.
- Reference official docs, WWDC sessions, or sample projects when introducing new APIs.
- Keep architectural rationale and trade-offs close to the code (doc comments or dedicated markdown) when complexity grows.
- Call out changes to generated assets or DevKit scripts (`FlowDown/DerivedSources`, `Resources/DevKit/scripts/`) in PR summaries so reviewers can trace automation impacts.

## Collaboration Workflow
- Craft concise, capitalized commit subjects (e.g., `Adjust Compiler Settings`) and use bodies to explain decisions or link issues (`#123`).
- Group related work per commit and avoid bundling unrelated refactors.
- Pull requests must include a summary, testing checklist, and before/after visuals for UI changes. Mention localization or asset updates when relevant.
- Tag reviewers responsible for the affected modules and outline any follow-up tasks or risks.

## Localization Guidelines
- Always use `String(localized: "text")` for user-facing strings instead of hardcoded text
- Add new localized strings to `FlowDown/Resources/Localizable.xcstrings` when introducing new UI text
- Use the provided scripts to manage translations:
  - `python3 Resources/DevKit/scripts/update_missing_i18n.py FlowDown/Resources/Localizable.xcstrings` to scaffold new keys (extend `NEW_STRINGS` as required)
  - `python3 Resources/DevKit/scripts/translate_missing.py FlowDown/Resources/Localizable.xcstrings` to apply curated zh-Hans translations
  - `python3 Resources/DevKit/scripts/check_untranslated.py FlowDown/Resources/Localizable.xcstrings` to surface untranslated entries
  - `python3 Resources/DevKit/scripts/check_translations.py FlowDown/Resources/Localizable.xcstrings` to remove stale keys and verify completeness
- Localization files such as `Localizable.xcstrings` exceed 10k lines; update the supporting Python scripts to regenerate changes instead of editing the JSON directly.
- Follow existing localization patterns and maintain consistency with the codebase. Avoid manual edits to `.xcstrings`; let scripts manage JSON structure.
