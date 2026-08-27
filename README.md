<div align="center">

**English · [Русский](README_RU.md)**

# DockPilot

**Task-focused Dock profiles for macOS**

[![Build](https://github.com/PEDZEO/DockPilot/actions/workflows/build.yml/badge.svg)](https://github.com/PEDZEO/DockPilot/actions/workflows/build.yml)
![macOS 14.6+](https://img.shields.io/badge/macOS-14.6%2B-black?logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-black?logo=apple)
![License](https://img.shields.io/badge/license-non--commercial-blue)

DockPilot saves different sets of apps, folders, and websites in the macOS Dock
and switches between them from the menu bar or with global keyboard shortcuts.

<img width="956" alt="DockPilot profile management interface" src="https://github.com/user-attachments/assets/96964473-f437-4809-952f-39a3ab9b528d" />

</div>

## Why DockPilot?

A single Dock quickly becomes crowded with development tools, entertainment,
and rarely used apps. DockPilot lets you create focused profiles such as:

- **Work** — VS Code, Warp, Termius, Safari, and Mail;
- **Personal** — Telegram, music, YouTube, and Twitch;
- **Gaming** — Steam, Discord, and game launchers.

Applying a profile updates the native macOS Dock. There is no replacement Dock,
extra taskbar, or separate launcher to manage.

## Features

- unlimited Dock profiles;
- apps, folders, links, and spacers inside a profile;
- quick switching from the macOS menu bar;
- global shortcuts from `⌥1` through `⌥9`;
- per-profile shortcut assignment with automatic conflict resolution;
- English and Russian interface languages, switchable without restarting;
- capture the current Dock into a selected profile;
- profile backup import and export;
- automatic update checks against DockPilot GitHub releases;
- local operation with no account or telemetry;
- launch automatically at login.

## Keyboard shortcuts

Non-default profiles receive initial shortcuts in their displayed order. You
can then change or disable each assignment under **Settings → Global Shortcuts**:

| Profile | Shortcut |
|---|---:|
| First | `⌥1` |
| Second | `⌥2` |
| Third | `⌥3` |
| … | … |
| Ninth | `⌥9` |

Shortcuts work globally while DockPilot is running. For example, you can apply
the Work profile with `⌥1` without opening the app window.

## Installation

### Prebuilt app

1. Open the latest successful run under
   [Actions](https://github.com/PEDZEO/DockPilot/actions/workflows/build.yml).
2. Download the **DockPilot-arm64** artifact at the bottom of the run page.
3. Extract the archive and move `DockPilot.app` into Applications.

GitHub Actions builds use an ad-hoc signature and are not notarized by Apple.
On first launch, macOS may ask you to approve the app under Privacy & Security.

### Build from source

Building locally requires macOS 14.6 or later and Xcode 26:

```bash
git clone https://github.com/PEDZEO/DockPilot.git
cd DockPilot
open apps/DockPilot/DockPilot.xcodeproj
```

## Continuous integration

Every push and pull request is built with GitHub Actions. A successful `main`
build produces `DockPilot-arm64.zip`, retained as an artifact for 14 days.

## Roadmap

- automatic switching with macOS Focus modes;
- a dedicated gaming-profile workflow;
- signed and notarized releases.

## License

DockPilot is available for non-commercial use under the inherited license. See
[LICENSE](LICENSE) for the complete terms and required copyright notice.

## Acknowledgements

Native Dock management is powered by
[dockutil](https://github.com/kcrawford/dockutil).
