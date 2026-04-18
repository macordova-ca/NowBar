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
        let combined = "\(name) - \(artist)"
        let maxLen = 30
        let shortened = combined.count > maxLen ? String(combined.prefix(maxLen)) + "…" : combined
        return "\(icon) \(shortened)"
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

enum PanelMode { case player, settings, contextMenu }

final class UIState: ObservableObject {
    @Published var mode: PanelMode = .player
}

// MARK: - Root view

struct RootView: View {
    @ObservedObject var state: SpotifyState
    @ObservedObject var settings: AppSettings
    @ObservedObject var ui: UIState
    let onQuit: () -> Void

    var body: some View {
        switch ui.mode {
        case .player:
            PopoverView(state: state, settings: settings)
        case .settings:
            SettingsView(settings: settings)
        case .contextMenu:
            ContextMenuView(
                onSettings: { ui.mode = .settings },
                onQuit: onQuit
            )
        }
    }
}

// MARK: - Context menu view

struct ContextMenuView: View {
    let onSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            MenuRow(icon: "gearshape", label: "Settings", action: onSettings)
            Divider().padding(.vertical, 2)
            MenuRow(icon: "power", label: "Quit NowBar", action: onQuit)
        }
        .padding(6)
        .frame(width: 170)
    }
}

struct MenuRow: View {
    let icon: String
    let label: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .frame(width: 14)
                Text(label)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hover ? Color.primary.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Marquee text

struct MarqueeText: View {
    let text: String
    let font: Font

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var runID = UUID()

    private let gap: CGFloat = 40
    private let speed: Double = 30
    private let pause: Double = 1.2

    var body: some View {
        Text(" ")
            .font(font)
            .lineLimit(1)
            .opacity(0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(marquee, alignment: .leading)
            .background(containerReader)
            .clipped()
            .onChange(of: text) { _, _ in restart() }
            .onChange(of: textWidth) { _, _ in restart() }
            .onChange(of: containerWidth) { _, _ in restart() }
    }

    private var marquee: some View {
        let needsScroll = textWidth > containerWidth + 0.5
        return HStack(spacing: gap) {
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize()
                .background(textReader)
            if needsScroll {
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .offset(x: needsScroll ? offset : 0)
    }

    private var textReader: some View {
        GeometryReader { g in
            Color.clear
                .onAppear { textWidth = g.size.width }
                .onChange(of: g.size.width) { _, w in textWidth = w }
        }
    }

    private var containerReader: some View {
        GeometryReader { g in
            Color.clear
                .onAppear { containerWidth = g.size.width }
                .onChange(of: g.size.width) { _, w in containerWidth = w }
        }
    }

    private func restart() {
        let needsScroll = textWidth > containerWidth + 0.5
        offset = 0
        runID = UUID()
        let id = runID
        guard needsScroll else { return }
        let distance = textWidth + gap
        let duration = Double(distance) / speed
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) {
            guard id == runID else { return }
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                offset = -distance
            }
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
                                MarqueeText(text: t.name, font: .system(size: 13, weight: .semibold))
                            }
                            if settings.showArtist {
                                MarqueeText(text: t.artist, font: .system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            if settings.showAlbum {
                                MarqueeText(text: t.album, font: .system(size: 10))
                                    .foregroundStyle(.tertiary)
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
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if settings.showVolume {
                            VerticalVolumeSlider(state: state)
                        }
                    }

                    if settings.showProgress {
                        ProgressSlider(state: state)
                    }
                }
                .padding(12)
                .frame(width: 360)
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

// MARK: - Container with dynamic border

final class PanelContainerView: NSView {
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.borderColor = NSColor.separatorColor.cgColor
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var hosting: NSHostingController<RootView>!
    private let state = SpotifyState()
    private let settings = AppSettings()
    private let ui = UIState()
    private var refreshTimer: Timer?
    private var tickTimer: Timer?
    private var outsideClickMonitor: Any?
    private var modeCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "♪ —"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleClick(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        hosting = NSHostingController(rootView: RootView(
            state: state,
            settings: settings,
            ui: ui,
            onQuit: { NSApp.terminate(nil) }
        ))
        hosting.sizingOptions = [.preferredContentSize]

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 384, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        let container = PanelContainerView(frame: NSRect(x: 0, y: 0, width: 384, height: 200))
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor.separatorColor.cgColor

        let vibrant = NSVisualEffectView(frame: container.bounds)
        vibrant.material = .menu
        vibrant.blendingMode = .behindWindow
        vibrant.state = .active
        vibrant.autoresizingMask = [.width, .height]

        hosting.view.frame = vibrant.bounds
        hosting.view.autoresizingMask = [.width, .height]
        vibrant.addSubview(hosting.view)

        container.addSubview(vibrant)
        panel.contentView = container

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

        modeCancellable = ui.$mode
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.resizePanelForMode() }
            }
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
            if panel.isVisible && ui.mode == .contextMenu {
                hidePanel()
            } else {
                ui.mode = .contextMenu
                if panel.isVisible {
                    resizePanelForMode()
                } else {
                    showPanel()
                }
            }
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        if panel.isVisible {
            hidePanel()
        } else {
            ui.mode = .player
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }
        state.refresh()
        updateBarTitle()

        hosting.view.layoutSubtreeIfNeeded()
        let size = hosting.view.fittingSize
        panel.setContentSize(size)

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameInScreen = buttonWindow.convertToScreen(buttonFrameInWindow)

        let targetX = buttonFrameInScreen.midX - size.width / 2
        let targetY = buttonFrameInScreen.minY - size.height - 6

        panel.alphaValue = 0
        panel.setFrameOrigin(NSPoint(x: targetX, y: targetY + 10))
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(NSPoint(x: targetX, y: targetY))
        }

        installOutsideClickMonitor()
    }

    private func resizePanelForMode() {
        guard panel.isVisible,
              let button = statusItem.button,
              let buttonWindow = button.window else { return }
        hosting.view.layoutSubtreeIfNeeded()
        let size = hosting.view.fittingSize
        let buttonFrameInScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let x = buttonFrameInScreen.midX - size.width / 2
        let y = buttonFrameInScreen.minY - size.height - 6
        let targetFrame = NSRect(origin: NSPoint(x: x, y: y), size: size)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    private func hidePanel() {
        removeOutsideClickMonitor()
        let origin = panel.frame.origin
        NSAnimationContext.runAnimationGroup({ [weak self] ctx in
            guard let self else { return }
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.panel.animator().alphaValue = 0
            self.panel.animator().setFrameOrigin(NSPoint(x: origin.x, y: origin.y + 8))
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
            self.panel.setFrameOrigin(origin)
        })
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.hidePanel()
        }
    }

    private func removeOutsideClickMonitor() {
        if let m = outsideClickMonitor {
            NSEvent.removeMonitor(m)
            outsideClickMonitor = nil
        }
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
