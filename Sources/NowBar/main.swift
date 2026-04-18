import AppKit
import SwiftUI
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Model

struct SpotifyTrack: Equatable {
    var name: String
    var artist: String
    var album: String
    var artUrl: String
    var isPlaying: Bool
    var shuffling: Bool
    var repeating: Bool
    var volume: Int
    var position: Double
    var duration: Double
    var isOff: Bool

    static let off = SpotifyTrack(name: "", artist: "", album: "", artUrl: "", isPlaying: false, shuffling: false, repeating: false, volume: 50, position: 0, duration: 0, isOff: true)

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
    @Published var vinylEnabled: Bool { didSet { save() } }
    @Published var accentFromArt: Bool { didSet { save() } }
    @Published var toastEnabled: Bool { didSet { save() } }
    @Published var toastPosition: String { didSet { save() } }

    init() {
        let d = UserDefaults.standard
        showImage = d.object(forKey: "showImage") as? Bool ?? true
        showTitle = d.object(forKey: "showTitle") as? Bool ?? true
        showArtist = d.object(forKey: "showArtist") as? Bool ?? true
        showAlbum = d.object(forKey: "showAlbum") as? Bool ?? true
        showVolume = d.object(forKey: "showVolume") as? Bool ?? true
        showProgress = d.object(forKey: "showProgress") as? Bool ?? true
        vinylEnabled = d.object(forKey: "vinylEnabled") as? Bool ?? false
        accentFromArt = d.object(forKey: "accentFromArt") as? Bool ?? false
        toastEnabled = d.object(forKey: "toastEnabled") as? Bool ?? false
        toastPosition = d.string(forKey: "toastPosition") ?? "bottomRight"
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(showImage, forKey: "showImage")
        d.set(showTitle, forKey: "showTitle")
        d.set(showArtist, forKey: "showArtist")
        d.set(showAlbum, forKey: "showAlbum")
        d.set(showVolume, forKey: "showVolume")
        d.set(showProgress, forKey: "showProgress")
        d.set(vinylEnabled, forKey: "vinylEnabled")
        d.set(accentFromArt, forKey: "accentFromArt")
        d.set(toastEnabled, forKey: "toastEnabled")
        d.set(toastPosition, forKey: "toastPosition")
    }
}

// MARK: - Liked store

final class LikedStore: ObservableObject {
    @Published private(set) var keys: Set<String>

    init() {
        let arr = UserDefaults.standard.stringArray(forKey: "likedKeys") ?? []
        keys = Set(arr)
    }

    func isLiked(_ t: SpotifyTrack) -> Bool {
        !t.isOff && keys.contains(Self.key(t))
    }

    func toggle(_ t: SpotifyTrack) {
        guard !t.isOff else { return }
        let k = Self.key(t)
        if keys.contains(k) { keys.remove(k) } else { keys.insert(k) }
        UserDefaults.standard.set(Array(keys), forKey: "likedKeys")
        SpotifyAPI.toggleLike()
    }

    private static func key(_ t: SpotifyTrack) -> String {
        "\(t.name)—\(t.artist)"
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
              set rp to repeating as string
              set v to sound volume as string
              set p to (player position) as string
              set d to ((duration of current track) / 1000) as string
              return t & "§" & a & "§" & al & "§" & u & "§" & s & "§" & sh & "§" & rp & "§" & v & "§" & p & "§" & d
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
        guard parts.count == 10 else { return .off }
        return SpotifyTrack(
            name: parts[0],
            artist: parts[1],
            album: parts[2],
            artUrl: parts[3],
            isPlaying: parts[4] == "playing",
            shuffling: parts[5] == "true",
            repeating: parts[6] == "true",
            volume: Int(parts[7]) ?? 50,
            position: parseNumber(parts[8]),
            duration: parseNumber(parts[9]),
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

    static func toggleRepeat(_ on: Bool) {
        _ = run("tell application \"Spotify\" to set repeating to \(on ? "true" : "false")")
    }

    static func toggleLike() {
        let source = """
        tell application "System Events"
          if exists (process "Spotify") then
            tell process "Spotify"
              keystroke "b" using {option down, shift down}
            end tell
          end if
        end tell
        """
        _ = run(source)
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
    var onTrackChange: ((SpotifyTrack) -> Void)?
    private var lastKey: String = ""

    func refresh() {
        let next = SpotifyAPI.currentTrack()
        let newKey = next.isOff ? "" : "\(next.name)—\(next.artist)"
        let changed = !next.isOff && !lastKey.isEmpty && newKey != lastKey
        if next != track { track = next }
        if changed { onTrackChange?(next) }
        lastKey = newKey
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
    @ObservedObject var liked: LikedStore
    let onQuit: () -> Void

    var body: some View {
        switch ui.mode {
        case .player:
            PopoverView(state: state, settings: settings, liked: liked)
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

// MARK: - Dominant color

enum ImageColor {
    private static var cache: [String: Color] = [:]

    static func dominant(urlString: String) async -> Color? {
        if let c = cache[urlString] { return c }
        guard let url = URL(string: urlString) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let nsImage = NSImage(data: data),
              let tiff = nsImage.tiffRepresentation,
              let ciImage = CIImage(data: tiff) else { return nil }
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = ciImage.extent
        guard let output = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        let ctx = CIContext(options: [.workingColorSpace: NSNull()])
        ctx.render(output,
                   toBitmap: &bitmap,
                   rowBytes: 4,
                   bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                   format: .RGBA8,
                   colorSpace: nil)
        let color = Color(
            red: Double(bitmap[0]) / 255.0,
            green: Double(bitmap[1]) / 255.0,
            blue: Double(bitmap[2]) / 255.0
        )
        cache[urlString] = color
        return color
    }
}

// MARK: - Album art view

struct AlbumArtView: View {
    let url: String
    let isPlaying: Bool
    let vinyl: Bool
    let size: CGFloat

    @State private var angle: Double = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: size, height: size)
            .clipShape(vinyl ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8)))
            .rotationEffect(.degrees(vinyl ? angle : 0))

            if vinyl {
                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: size * 0.22, height: size * 0.22)
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: size * 0.05, height: size * 0.05)
                    )
            }
        }
        .onAppear { updateTimer() }
        .onDisappear { timer?.invalidate() }
        .onChange(of: isPlaying) { _, _ in updateTimer() }
        .onChange(of: vinyl) { _, _ in updateTimer() }
    }

    private func updateTimer() {
        timer?.invalidate()
        guard vinyl, isPlaying else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            angle = angle.truncatingRemainder(dividingBy: 360) + 0.8
        }
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
    @ObservedObject var liked: LikedStore
    @State private var accent: Color? = nil

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
                            AlbumArtView(
                                url: t.artUrl,
                                isPlaying: t.isPlaying,
                                vinyl: settings.vinylEnabled,
                                size: 96
                            )
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

                            HStack(spacing: 5) {
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
                                ControlButton(system: "repeat", active: t.repeating) {
                                    SpotifyAPI.toggleRepeat(!t.repeating)
                                    state.refresh()
                                }
                                ControlButton(
                                    system: liked.isLiked(t) ? "heart.fill" : "heart",
                                    active: liked.isLiked(t)
                                ) {
                                    liked.toggle(t)
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
                .background(tintBackground)
                .task(id: t.artUrl) { await loadAccent(for: t.artUrl) }
                .onChange(of: settings.accentFromArt) { _, enabled in
                    if enabled {
                        Task { await loadAccent(for: t.artUrl) }
                    } else {
                        accent = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tintBackground: some View {
        if settings.accentFromArt, let c = accent {
            LinearGradient(
                colors: [c.opacity(0.35), c.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.clear
        }
    }

    private func loadAccent(for url: String) async {
        guard settings.accentFromArt, !url.isEmpty else { return }
        if let c = await ImageColor.dominant(urlString: url) {
            await MainActor.run { accent = c }
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
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(active ? Color.green : Color.primary)
                .frame(width: 28, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
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

struct GreenToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let on = configuration.isOn
        return RoundedRectangle(cornerRadius: 8)
            .fill(on ? Color.green : Color.secondary.opacity(0.4))
            .frame(width: 26, height: 15)
            .overlay(
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 0.5, y: 0.5)
                    .padding(1.5)
                    .frame(width: 15, height: 15)
                    .offset(x: on ? 5.5 : -5.5)
            )
            .animation(.easeInOut(duration: 0.15), value: on)
            .onTapGesture { configuration.isOn.toggle() }
    }
}

struct SettingsRow: View {
    let label: String
    @Binding var value: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Toggle("", isOn: $value)
                .labelsHidden()
                .toggleStyle(GreenToggleStyle())
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
            Divider()
            SettingsRow(label: "Vinyl animation", value: $settings.vinylEnabled)
            SettingsRow(label: "Theme from album art", value: $settings.accentFromArt)
            Divider()
            SettingsRow(label: "Song-change toast", value: $settings.toastEnabled)
            if settings.toastEnabled {
                HStack {
                    Text("Position")
                    Spacer()
                    Picker("", selection: $settings.toastPosition) {
                        Text("Top left").tag("topLeft")
                        Text("Top right").tag("topRight")
                        Text("Bottom left").tag("bottomLeft")
                        Text("Bottom right").tag("bottomRight")
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 110)
                }
            }
        }
        .font(.system(size: 11))
        .padding(12)
        .frame(width: 220)
    }
}

// MARK: - Toast

struct ToastView: View {
    let track: SpotifyTrack

    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: URL(string: track.artUrl)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: 260)
    }
}

final class ToastController {
    private var panel: NSPanel?
    private var hosting: NSHostingController<ToastView>?
    private var hideWork: DispatchWorkItem?

    func show(track: SpotifyTrack, position: String) {
        build()
        guard let panel, let hosting else { return }
        hosting.rootView = ToastView(track: track)
        hosting.view.layoutSubtreeIfNeeded()
        let size = hosting.view.fittingSize
        panel.setContentSize(size)

        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let margin: CGFloat = 12
        let origin: NSPoint
        switch position {
        case "topLeft":
            origin = NSPoint(x: visible.minX + margin, y: visible.maxY - size.height - margin)
        case "topRight":
            origin = NSPoint(x: visible.maxX - size.width - margin, y: visible.maxY - size.height - margin)
        case "bottomLeft":
            origin = NSPoint(x: visible.minX + margin, y: visible.minY + margin)
        default:
            origin = NSPoint(x: visible.maxX - size.width - margin, y: visible.minY + margin)
        }
        panel.setFrameOrigin(origin)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    private func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            panel?.orderOut(nil)
        })
    }

    private func build() {
        if panel != nil { return }
        let h = NSHostingController(rootView: ToastView(track: .off))
        h.sizingOptions = [.preferredContentSize]
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 62),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .statusBar
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.ignoresMouseEvents = true

        let container = NSView(frame: p.contentView!.bounds)
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor.separatorColor.cgColor

        let vibrant = NSVisualEffectView(frame: container.bounds)
        vibrant.material = .menu
        vibrant.blendingMode = .behindWindow
        vibrant.state = .active
        vibrant.autoresizingMask = [.width, .height]

        h.view.frame = vibrant.bounds
        h.view.autoresizingMask = [.width, .height]
        vibrant.addSubview(h.view)
        container.addSubview(vibrant)
        p.contentView = container

        panel = p
        hosting = h
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
    private let liked = LikedStore()
    private let toast = ToastController()
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
            liked: liked,
            onQuit: { NSApp.terminate(nil) }
        ))

        state.onTrackChange = { [weak self] track in
            guard let self, self.settings.toastEnabled else { return }
            self.toast.show(track: track, position: self.settings.toastPosition)
        }
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
        panel.setFrame(targetFrame, display: true)
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

let myPid = ProcessInfo.processInfo.processIdentifier
let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.canai.nowbar")
    .filter { $0.processIdentifier != myPid && $0.processIdentifier > 0 }
if !running.isEmpty {
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
