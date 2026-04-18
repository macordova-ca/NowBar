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
    var isOff: Bool

    static let off = SpotifyTrack(name: "", artist: "", album: "", artUrl: "", isPlaying: false, shuffling: false, volume: 50, isOff: true)

    var barTitle: String {
        if isOff { return "♪ —" }
        let icon = isPlaying ? "♪" : "⏸"
        let maxLen = 25
        let shortName = name.count > maxLen ? String(name.prefix(maxLen)) + "…" : name
        return "\(icon) \(shortName) - \(artist)"
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
              return t & "§" & a & "§" & al & "§" & u & "§" & s & "§" & sh & "§" & v
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
        guard parts.count == 7 else { return .off }
        return SpotifyTrack(
            name: parts[0],
            artist: parts[1],
            album: parts[2],
            artUrl: parts[3],
            isPlaying: parts[4] == "playing",
            shuffling: parts[5] == "true",
            volume: Int(parts[6]) ?? 50,
            isOff: false
        )
    }

    static func setVolume(_ value: Int) {
        _ = run("tell application \"Spotify\" to set sound volume to \(value)")
    }

    static func toggleShuffle(_ on: Bool) {
        _ = run("tell application \"Spotify\" to set shuffling to \(on ? "true" : "false")")
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
}

// MARK: - Popover view

struct PopoverView: View {
    @ObservedObject var state: SpotifyState

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
                HStack(alignment: .top, spacing: 12) {
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

                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(t.artist)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(t.album)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .padding(.bottom, 8)

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

                    VerticalVolumeSlider(state: state)
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

struct VerticalVolumeSlider: View {
    @ObservedObject var state: SpotifyState
    @State private var localValue: Double = 50
    @State private var dragging = false

    private let trackWidth: CGFloat = 4
    private let knob: CGFloat = 12
    private let sliderHeight: CGFloat = 60

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: trackWidth, height: sliderHeight)
                Capsule()
                    .fill(Color.secondary.opacity(0.55))
                    .frame(width: trackWidth, height: sliderHeight * CGFloat(localValue / 100))
                Circle()
                    .fill(Color.primary.opacity(0.9))
                    .frame(width: knob, height: knob)
                    .offset(y: -(sliderHeight - knob / 2) * CGFloat(localValue / 100) + knob / 2)
            }
            .frame(width: 20, height: sliderHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        dragging = true
                        let y = max(0, min(sliderHeight, g.location.y))
                        let pct = 1 - Double(y / sliderHeight)
                        localValue = pct * 100
                        SpotifyAPI.setVolume(Int(localValue))
                    }
                    .onEnded { _ in
                        dragging = false
                        SpotifyAPI.setVolume(Int(localValue))
                    }
            )

            Text("\(Int(localValue))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 22)
        }
        .onAppear { localValue = Double(state.track.volume) }
        .onChange(of: state.track.volume) { _, newValue in
            if !dragging { localValue = Double(newValue) }
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

struct VolumeSlider: View {
    @ObservedObject var state: SpotifyState
    @State private var localValue: Double = 50
    @State private var editing = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Slider(
                value: $localValue,
                in: 0...100,
                onEditingChanged: { active in
                    editing = active
                    if !active {
                        SpotifyAPI.setVolume(Int(localValue))
                    }
                }
            )
            .controlSize(.small)
            .tint(Color.secondary.opacity(0.5))
            Text("\(Int(localValue))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)
        }
        .onAppear { localValue = Double(state.track.volume) }
        .onChange(of: state.track.volume) { _, newValue in
            if !editing { localValue = Double(newValue) }
        }
        .onChange(of: localValue) { _, newValue in
            if editing { SpotifyAPI.setVolume(Int(newValue)) }
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

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let state = SpotifyState()
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "♪ —"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))

        popover = NSPopover()
        popover.behavior = .transient
        let hosting = NSHostingController(rootView: PopoverView(state: state))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting

        state.refresh()
        updateBarTitle()

        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.state.refresh()
            self?.updateBarTitle()
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

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            state.refresh()
            updateBarTitle()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
