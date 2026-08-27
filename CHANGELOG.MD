# Changelog

## 0.2.2

- Made profile switching asynchronous, serialized, and faster when the Dock already matches.
- Preserved the macOS Apps launcher instead of recreating its private system tile.
- Fixed false profile failures caused by recent apps, mixed Dock sections, and Unicode paths.
- Added reliable spacer support and stricter profile verification.
- Reused one lightweight animated status panel and respected Reduce Motion.
- Moved application discovery off the main thread and reduced unnecessary icon work.
- Fixed profile creation, deletion, backup restore, and shortcut lifecycle edge cases.

## 0.2.0

- Added English and Russian interface languages with instant switching.
- Added customizable and conflict-safe shortcuts for individual profiles.
- Moved shortcut orchestration and persistence into dedicated services.
- Added an original DockPilot app icon and complete macOS icon set.
- Added unit tests to the GitHub Actions pipeline.

## 0.1.0

- Established DockPilot as an independent public repository.
- Added global `⌥1` through `⌥9` profile shortcuts.
- Added GitHub Actions builds for Apple Silicon.
- Rebranded the application, bundle identifier, preferences, and updater.
