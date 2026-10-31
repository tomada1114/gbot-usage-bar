# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial project scaffold from [macos-app-template](https://github.com/tomada1114/macos-app-template)
- A menu-bar agent that shows the desktop app's weekly usage as a rounded percentage
  inside a template-tinted rounded rectangle (`--` until the first good read)
- A menu with the weekly usage, the weekday, date, and time it resets, when the
  desktop app read it, a line naming why the last read failed or why the numbers may be
  stale, and Quit (⌘Q)
- A monochrome warning mark before the badge whenever the last read failed or the
  numbers may be stale
- A read at launch and every minute of the weekly usage the desktop app saves in its
  local cache — no network request, no keychain access, and no write to its folder

### Removed

- The template's example counter screen and frontmost-application example

[Unreleased]: https://github.com/tomada1114/gbot-usage-bar/commits/main
