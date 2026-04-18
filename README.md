# NowBar

Native macOS menu bar app for Spotify. Built with Swift + SwiftUI + AppKit.

## Features

- Track info in menu bar (song - artist)
- Popover with album art, title, artist, album
- Playback controls: prev, play/pause, next
- Shuffle toggle
- Vertical volume slider
- Instant updates via `com.spotify.client.PlaybackStateChanged`

## Requirements

- macOS 14+
- Spotify desktop app
- Swift 5.9+

## Build

```bash
swift build -c release
```

Binary at `.build/release/NowBar`.

## Install as app

```bash
APP=/Applications/NowBar.app
mkdir -p "$APP/Contents/MacOS"
cp .build/release/NowBar "$APP/Contents/MacOS/NowBar"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
open "$APP"
```

## Auto-start at login

```bash
cp com.canai.nowbar.plist ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/com.canai.nowbar.plist
```

## Stack

- Swift + SwiftUI + AppKit (`NSStatusItem`, `NSPopover`)
- AppleScript bridge via `NSAppleScript`
- `DistributedNotificationCenter` for Spotify events
- `launchd` LaunchAgent for auto-start
