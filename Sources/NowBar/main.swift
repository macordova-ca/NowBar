import AppKit
import SwiftUI
import Combine

// MARK: - Model

struct SpotifyTrack: Equatable {
    var name: String
    var artist: String
    var album: String
    var artUrl: String
    var isPlaying: Bool
    var shuffling: Bool
    var volume: Int
    var position: Double
    var duration: Double
    var isOff: Bool

    static let off = SpotifyTrack(name: "", artist: "", album: "", artUrl: "", isPlaying: false, shuffling: false, volume: 50, position: 0, duration: 0, isOff: true)

    var barTitle: String {
        if isOff { return "♪ —" }
        let icon = isPlaying ? "♪" : "⏸"
        let maxLen = 25
        let shortName = name.count > maxLen ? String(name.prefix(maxLen)) + "…" : name
        return "\(icon) \(shortName) - \(artist)"
    }
}

// MARK: - Settings

final class AppSettings: ObservableObject {
    @Published var showImage: Bool { didSet { save() } }
    @Published var showTitle: Bool { didSet { save() } }
    @Published var showArtist: Bool { didSet { save() } }
    @Published var showAlbum: Bool { didSet { save() } }
    @Published var showVolume: Bool { didSet { save() } }
    @Published var showProgress: Bool { didSet { save() } }

    init() {
        let d = UserDefaults.standard
        showImage = d.object(forKey: "showImage") as? Bool ?? true
        showTitle = d.object(forKey: "showTitle") as? Bool ?? true
        showArtist = d.object(forKey: "showArtist") as? Bool ?? true
        showAlbum = d.object(forKey: "showAlbum") as? Bool ?? true
        showVolume = d.object(forKey: "showVolume") as? Bool ?? true
        showProgress = d.object(forKey: "showProgress") as? Bool ?? true
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(showImage, forKey: "showImage")
        d.set(showTitle, forKey: "showTitle")
        d.set(showArtist, forKey: "showArtist")
        d.set(showAlbum, forKey: "showAlbum")
        d.set(showVolume, forKey: "showVolume")
        d.set(showProgress, forKey: "showProgress")
    }
}

// MARK: - AppleScript bridge

enum SpotifyAPI {
    static func currentTrack() -> SpotifyTrack {
        let script = """
        tell application "Spotify"
          if it is running then
            try
              set t to name of current track
              set a to artist of current track
              set al to album of current track
              set u to artwork url of current track
              set s to player state as string
              set sh to shuffling as string
              set v to sound volume as string
              set p to (player position) as string
              set d to ((duration of current track) / 1000) as string
              return t & "§" & a & "§" & al & "§" & u & "§" & s & "§" & sh & "§" & v & "§" & p & "§" & d
            on error
              return "off"
            end try
          else
            return "off"
          end if
        end tell
        """
        guard let raw = run(script), raw != "off" else { return .off }
        let parts = raw.components(separatedBy: "§")
        guard parts.count == 9 else { return .off }
        return SpotifyTrack(
            name: parts[0],
            artist: parts[1],
            album: parts[2],
            artUrl: parts[3],
            isPlaying: parts[4] == "playing",
            shuffling: parts[5] == "true",
            volume: Int(parts[6]) ?? 50,
            position: parseNumber(parts[7]),
            duration: parseNumber(parts[8]),
            isOff: false
        )
    }

    private static func parseNumber(_ s: String) -> Double {
        let normalized = s.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    static func setVolume(_ value: Int) {
        _ = run("tell application \"Spotify\" to set sound volume to \(value)")
    }

    static func toggleShuffle(_ on: Bool) {
        _ = run("tell application \"Spotify\" to set shuffling to \(on ? "true" : "false")")
    }

    static func seek(_ seconds: Double) {
        _ = run("tell application \"Spotify\" to set player position to \(seconds)")
    }

    static func perform(_ action: String) {
        _ = run("tell application \"Spotify\" to \(action)")
    }

    @discardableResult
    private static func run(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        return result.stringValue
    }
}

// MARK: - Shared state

final class SpotifyState: ObservableObject {
    @Published var track: SpotifyTrack = .off

    func refresh() {
        let next = SpotifyAPI.currentTrack()
        if next != track { track = next }
    }

    func tickPosition() {
        guard !track.isOff, track.isPlaying else { return }
        let next = min(track.position + 1, track.duration)
        track.position = next
    }
}

// MARK: - UI state

final class UIState: ObservableObject {
    @Published var showingSettings = false
}

// MARK: - Root view

struct RootView: View {
    @ObservedObject var state: SpotifyState
    @ObservedObject var settings: AppSettings
    @ObservedObject var ui: UIState

    var body: some View {
        if ui.showingSettings {
            SettingsView(settings: settings)
        } else {
            PopoverView(state: state, settings: settings)
        }
    }
}

// MARK: - Popover view

struct PopoverView: View {
    @ObservedObject var state: SpotifyState
    @ObservedObject var settings: AppSettings

    var body: some View {
        let t = state.track
        Group {
            if t.isOff {
                VStack {
                    Text("♪ Spotify off")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 320, height: 120)
            } else {
                VStack(spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        if settings.showImage {
                            AsyncImage(url: URL(string: t.artUrl)) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Rectangle().fill(.quaternary)
                                }
                            }
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            if settings.showTitle {
                                Text(t.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            if settings.showArtist {
                                Text(t.artist)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            if settings.showAlbum {
                                Text(t.album)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .padding(.bottom, 8)
                            }

                            HStack(spacing: 6) {
                                ControlButton(system: "backward.fill") {
                                    SpotifyAPI.perform("previous track")
                                    state.refresh()
                                }
                                ControlButton(system: t.isPlaying ? "pause.fill" : "play.fill") {
                                    SpotifyAPI.perform("playpause")
                                    state.refresh()
                                }
                                ControlButton(system: "forward.fill") {
                                    SpotifyAPI.perform("next track")
                                    state.refresh()
                                }
                                ControlButton(system: "shuffle", active: t.shuffling) {
                                    SpotifyAPI.toggleShuffle(!t.shuffling)
                                    state.refresh()
                                }
                            }
                        }

                        if settings.showVolume {
                            VerticalVolumeSlider(state: state)
                        }
                    }

                    if settings.showProgress {
                        ProgressSlider(state: state)
                    }
                }
                .padding(12)
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}

struct ControlButton: View {
    let system: String
    var active: Bool = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(active ? Color.green : Color.primary)
                .frame(width: 32, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(backgroundColor)
                )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }

    private var backgroundColor: Color {
        if active { return Color.green.opacity(hover ? 0.25 : 0.15) }
        return Color.primary.opacity(hover ? 0.15 : 0.08)
    }
}

// MARK: - Shared slider primitive

enum SliderAxis { case horizontal, vertical }

struct TrackSlider: View {
    let axis: SliderAxis
    let fraction: Double
    let onChanged: (Double) -> Void
    let onEnded: () -> Void

    @State private var hover = false
    @State private var dragging = false

    private let trackThickness: CGFloat = 4
    private let knob: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let total = axis == .horizontal ? geo.size.width : geo.size.height
            let frac = CGFloat(max(0, min(1, fraction)))
            let showKnob = hover || dragging

            ZStack(alignment: axis == .horizontal ? .leading : .bottom) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(
                        width: axis == .horizontal ? total : trackThickness,
                        height: axis == .horizontal ? trackThickness : total
                    )
                Capsule()
                    .fill(Color.secondary.opacity(0.55))
                    .frame(
                        width: axis == .horizontal ? total * frac : trackThickness,
                        height: axis == .horizontal ? trackThickness : total * frac
                    )
                if showKnob {
                    Circle()
                        .fill(Color.primary.opacity(0.9))
                        .frame(width: knob, height: knob)
                        .offset(
                            x: axis == .horizontal ? total * frac - knob / 2 : 0,
                            y: axis == .vertical ? -(total - knob / 2) * frac + knob / 2 : 0
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height,
                   alignment: axis == .horizontal ? .leading : .bottom)
            .contentShape(Rectangle())
            .onHover { hover = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        dragging = true
                        guard total > 0 else { return }
                        let pct: Double
                        if axis == .horizontal {
                            let x = max(0, min(total, g.location.x))
                            pct = Double(x / total)
                        } else {
                            let y = max(0, min(total, g.location.y))
                            pct = 1 - Double(y / total)
                        }
                        onChanged(pct)
                    }
                    .onEnded { _ in
                        dragging = false
                        onEnded()
                    }
            )
        }
    }
}

// MARK: - Slider wrappers

struct VerticalVolumeSlider: View {
    @ObservedObject var state: SpotifyState
    @State private var localValue: Double = 50
    @State private var editing = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            TrackSlider(
                axis: .vertical,
                fraction: localValue / 100,
                onChanged: { pct in
                    editing = true
                    localValue = pct * 100
                    SpotifyAPI.setVolume(Int(localValue))
                },
                onEnded: {
                    SpotifyAPI.setVolume(Int(localValue))
                    editing = false
                }
            )
            .frame(width: 20, height: 60)

            Text("\(Int(localValue))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 22)
        }
        .onAppear { localValue = Double(state.track.volume) }
        .onChange(of: state.track.volume) { _, newValue in
            if !editing { localValue = Double(newValue) }
        }
    }

    private var iconName: String {
        let v = localValue
        if v == 0 { return "speaker.slash.fill" }
        if v < 33 { return "speaker.wave.1.fill" }
        if v < 66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

struct ProgressSlider: View {
    @ObservedObject var state: SpotifyState
    @State private var localValue: Double = 0
    @State private var editing = false

    var body: some View {
        let duration = max(state.track.duration, 0.01)
        VStack(spacing: 3) {
            TrackSlider(
                axis: .horizontal,
                fraction: localValue / duration,
                onChanged: { pct in
                    editing = true
                    localValue = pct * duration
                },
                onEnded: {
                    SpotifyAPI.seek(localValue)
                    state.track.position = localValue
                    editing = false
                }
            )
            .frame(height: 10)

            HStack {
                Text(format(localValue))
                Spacer()
                Text(format(duration))
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .onAppear { localValue = state.track.position }
        .onChange(of: state.track.position) { _, newValue in
            if !editing { localValue = newValue }
        }
    }

    private func format(_ s: Double) -> String {
        let total = Int(s)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Settings view

struct SettingsRow: View {
    let label: String
    @Binding var value: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Toggle("", isOn: $value)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
            Divider()
            SettingsRow(label: "Album image", value: $settings.showImage)
            SettingsRow(label: "Song name", value: $settings.showTitle)
            SettingsRow(label: "Artist", value: $settings.showArtist)
            SettingsRow(label: "Album", value: $settings.showAlbum)
            SettingsRow(label: "Volume slider", value: $settings.showVolume)
            SettingsRow(label: "Progress slider", value: $settings.showProgress)
        }
        .font(.system(size: 11))
        .padding(12)
        .frame(width: 220)
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let state = SpotifyState()
    private let settings = AppSettings()
    private let ui = UIState()
    private var refreshTimer: Timer?
    private var tickTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "♪ —"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleClick(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        popover = NSPopover()
        popover.behavior = .transient
        let hosting = NSHostingController(rootView: RootView(state: state, settings: settings, ui: ui))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting

        state.refresh()
        updateBarTitle()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.state.refresh()
            self?.updateBarTitle()
        }

        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.state.tickPosition()
        }

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(spotifyChanged),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
    }

    @objc private func spotifyChanged() {
        DispatchQueue.main.async {
            self.state.refresh()
            self.updateBarTitle()
        }
    }

    private func updateBarTitle() {
        statusItem.button?.title = state.track.barTitle
    }

    @objc private func handleClick(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        let item = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        item.target = self
        menu.addItem(item)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit NowBar", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        ui.showingSettings = true
        showPopover()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            ui.showingSettings = false
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        state.refresh()
        updateBarTitle()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
