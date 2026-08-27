# DockPilot

DockPilot is a local macOS utility for saving and switching between Dock
profiles. Keep separate layouts for work, personal apps, games, or individual
projects and activate them from the menu bar or keyboard.

## Features

- Create multiple Dock profiles with different apps, URLs, and folders
- Quick profile switching from the menu bar
- Global keyboard shortcuts for instant profile changes (`⌥1` through `⌥9`)
- Import/export profiles to share or backup
- Automatic update notifications from DockPilot GitHub releases
- Works completely offline

## Requirements

- macOS 14.6 or later
- Apple Silicon for downloadable CI artifacts

## Global shortcuts

Non-default profiles are assigned `⌥1` through `⌥9` in their displayed order.
The shortcuts work anywhere in macOS while DockPilot is running.

Every push to `main` is built by GitHub Actions. Successful runs publish an
ad-hoc-signed Apple Silicon app as a downloadable artifact.

## License

This derivative remains available for non-commercial use under the inherited
license. See [LICENSE](LICENSE) for the complete terms and required copyright
notice.

## Credits

Dock management is powered by [dockutil](https://github.com/kcrawford/dockutil).
