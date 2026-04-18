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
    @Published var statsAsked: Bool { didSet { save() } }
    @Published var statsEnabled: Bool { didSet { save() } }
    @Published var statsPlayCount: Bool { didSet { save() } }
    @Published var statsSkipCount: Bool { didSet { save() } }
    @Published var statsDailyMinutes: Bool { didSet { save() } }
    @Published var statsArtistPlays: Bool { didSet { save() } }
    @Published var language: String { didSet { save() } }

    init() {
        let d = UserDefaults.standard
        let sysLang = Locale.current.language.languageCode?.identifier ?? "en"
        let defaultLang: String = {
            switch sysLang {
            case "es": return "es"
            case "zh": return "zh"
            default: return "en"
            }
        }()
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
        statsAsked = d.object(forKey: "statsAsked") as? Bool ?? false
        statsEnabled = d.object(forKey: "statsEnabled") as? Bool ?? false
        statsPlayCount = d.object(forKey: "statsPlayCount") as? Bool ?? true
        statsSkipCount = d.object(forKey: "statsSkipCount") as? Bool ?? true
        statsDailyMinutes = d.object(forKey: "statsDailyMinutes") as? Bool ?? true
        statsArtistPlays = d.object(forKey: "statsArtistPlays") as? Bool ?? true
        language = d.string(forKey: "language") ?? defaultLang
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
        d.set(statsAsked, forKey: "statsAsked")
        d.set(statsEnabled, forKey: "statsEnabled")
        d.set(statsPlayCount, forKey: "statsPlayCount")
        d.set(statsSkipCount, forKey: "statsSkipCount")
        d.set(statsDailyMinutes, forKey: "statsDailyMinutes")
        d.set(statsArtistPlays, forKey: "statsArtistPlays")
        d.set(language, forKey: "language")
    }
}

// MARK: - Localization

enum L10n {
    static let table: [String: [String: String]] = [
        "spotify_off": [
            "en": "♪ Spotify off",
            "es": "♪ Spotify apagado",
            "zh": "♪ Spotify 已关闭"
        ],
        "now_playing": [
            "en": "Now Playing…",
            "es": "Reproduciendo…",
            "zh": "正在播放…"
        ],
        "settings": ["en": "Settings", "es": "Ajustes", "zh": "设置"],
        "album_image": ["en": "Album image", "es": "Portada del álbum", "zh": "专辑封面"],
        "song_name": ["en": "Song name", "es": "Nombre de canción", "zh": "歌曲名"],
        "artist": ["en": "Artist", "es": "Artista", "zh": "艺术家"],
        "album": ["en": "Album", "es": "Álbum", "zh": "专辑"],
        "volume_slider": ["en": "Volume slider", "es": "Control de volumen", "zh": "音量滑块"],
        "progress_slider": ["en": "Progress slider", "es": "Barra de progreso", "zh": "进度滑块"],
        "vinyl_animation": ["en": "Vinyl animation", "es": "Animación de vinilo", "zh": "黑胶动画"],
        "theme_from_art": ["en": "Theme from album art", "es": "Tema desde portada", "zh": "从封面取主题"],
        "toast_song_change": ["en": "Song-change toast", "es": "Aviso al cambiar canción", "zh": "切歌提示"],
        "position": ["en": "Position", "es": "Posición", "zh": "位置"],
        "top_left": ["en": "Top left", "es": "Arriba izquierda", "zh": "左上"],
        "top_right": ["en": "Top right", "es": "Arriba derecha", "zh": "右上"],
        "bottom_left": ["en": "Bottom left", "es": "Abajo izquierda", "zh": "左下"],
        "bottom_right": ["en": "Bottom right", "es": "Abajo derecha", "zh": "右下"],
        "stats": ["en": "Stats", "es": "Estadísticas", "zh": "统计"],
        "view_stats": ["en": "View stats", "es": "Ver estadísticas", "zh": "查看统计"],
        "enable_stats": ["en": "Enable stats", "es": "Activar estadísticas", "zh": "启用统计"],
        "clear_stats": ["en": "Clear all stats", "es": "Borrar todas", "zh": "清除所有"],
        "data_local": [
            "en": "Data stored locally only",
            "es": "Los datos se guardan solo localmente",
            "zh": "数据仅存于本地"
        ],
        "enable_stats_q": [
            "en": "Enable listening stats?",
            "es": "¿Activar estadísticas de escucha?",
            "zh": "启用听歌统计？"
        ],
        "stats_description": [
            "en": "Track play counts, skips, minutes per day, and per-artist plays. Data stays on this Mac — nothing leaves the device.",
            "es": "Registra reproducciones, saltos, minutos por día y reproducciones por artista. Los datos quedan en este Mac — nada sale del dispositivo.",
            "zh": "记录播放次数、跳过、每日分钟数以及每位艺术家的播放数。数据仅留在本机 — 不发送到任何地方。"
        ],
        "enable": ["en": "Enable", "es": "Activar", "zh": "启用"],
        "not_now": ["en": "Not now", "es": "Ahora no", "zh": "暂不"],
        "play_count_song": ["en": "Play count per song", "es": "Reproducciones por canción", "zh": "每首播放次数"],
        "skip_count_song": ["en": "Skip count per song", "es": "Saltos por canción", "zh": "每首跳过次数"],
        "minutes_per_day": ["en": "Minutes per day", "es": "Minutos por día", "zh": "每日分钟"],
        "plays_per_artist": ["en": "Plays per artist", "es": "Reproducciones por artista", "zh": "每位艺术家播放次数"],
        "tracking": ["en": "Tracking", "es": "Registrando", "zh": "记录项"],
        "your_stats": ["en": "Your Stats", "es": "Tus estadísticas", "zh": "你的统计"],
        "no_data": [
            "en": "No data yet. Keep listening — stats will appear here.",
            "es": "Aún no hay datos. Sigue escuchando — las estadísticas aparecerán aquí.",
            "zh": "暂无数据。继续听 — 统计会出现在这里。"
        ],
        "top_tracks": ["en": "Top tracks", "es": "Top canciones", "zh": "热门歌曲"],
        "top_artists": ["en": "Top artists", "es": "Top artistas", "zh": "热门艺术家"],
        "last_7_days": ["en": "Last 7 days", "es": "Últimos 7 días", "zh": "最近 7 天"],
        "plays": ["en": "Plays", "es": "Reproducciones", "zh": "播放"],
        "skips": ["en": "Skips", "es": "Saltos", "zh": "跳过"],
        "minutes": ["en": "Minutes", "es": "Minutos", "zh": "分钟"],
        "quit": ["en": "Quit NowBar", "es": "Cerrar NowBar", "zh": "退出 NowBar"],
        "language": ["en": "Language", "es": "Idioma", "zh": "语言"]
    ]

    static func t(_ key: String, _ lang: String) -> String {
        table[key]?[lang] ?? table[key]?["en"] ?? key
    }
}

func tr(_ key: String, _ lang: String) -> String { L10n.t(key, lang) }

// MARK: - Stats store

final class StatsStore: ObservableObject {
    struct Data: Codable {
        var plays: [String: Int] = [:]
        var skips: [String: Int] = [:]
        var artistPlays: [String: Int] = [:]
        var dailyMinutes: [String: Double] = [:]
    }

    @Published private(set) var data = Data()
    private var currentKey: String = ""
    private var currentArtist: String = ""
    private var currentSeconds: Double = 0
    weak var settings: AppSettings?

    init() { load() }

    func tick(_ t: SpotifyTrack) {
        guard let s = settings, s.statsEnabled, !t.isOff, t.isPlaying else { return }
        let key = Self.trackKey(t)
        if key != currentKey {
            commit()
            currentKey = key
            currentArtist = t.artist
            currentSeconds = 0
        }
        currentSeconds += 1
        if s.statsDailyMinutes {
            let day = Self.todayKey()
            data.dailyMinutes[day, default: 0] += 1.0 / 60.0
        }
        save()
    }

    func trackChanged(to t: SpotifyTrack) {
        commit()
        currentKey = t.isOff ? "" : Self.trackKey(t)
        currentArtist = t.artist
        currentSeconds = 0
    }

    private func commit() {
        guard let s = settings, s.statsEnabled, !currentKey.isEmpty else { return }
        if currentSeconds >= 30 {
            if s.statsPlayCount { data.plays[currentKey, default: 0] += 1 }
            if s.statsArtistPlays, !currentArtist.isEmpty {
                data.artistPlays[currentArtist, default: 0] += 1
            }
        } else if currentSeconds > 0, s.statsSkipCount {
            data.skips[currentKey, default: 0] += 1
        }
        save()
    }

    private static func trackKey(_ t: SpotifyTrack) -> String { "\(t.name)—\(t.artist)" }

    private static func todayKey() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private static var fileURL: URL {
        let fm = FileManager.default
        let base = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                               appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("NowBar", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("stats.json")
    }

    private func load() {
        guard let raw = try? Foundation.Data(contentsOf: Self.fileURL) else { return }
        if let decoded = try? JSONDecoder().decode(Data.self, from: raw) {
            data = decoded
        }
    }

    private func save() {
        if let enc = try? JSONEncoder().encode(data) {
            try? enc.write(to: Self.fileURL, options: .atomic)
        }
    }

    func reset() {
        data = Data()
        save()
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

enum PanelMode { case player, settings, contextMenu, stats, statsData }

final class UIState: ObservableObject {
    @Published var mode: PanelMode = .player
}

// MARK: - Root view

struct RootView: View {
    @ObservedObject var state: SpotifyState
    @ObservedObject var settings: AppSettings
    @ObservedObject var ui: UIState
    @ObservedObject var stats: StatsStore
    let onQuit: () -> Void

    var body: some View {
        switch ui.mode {
        case .player:
            PopoverView(state: state, settings: settings)
        case .settings:
            SettingsView(settings: settings, onOpenStats: { ui.mode = .stats })
        case .contextMenu:
            ContextMenuView(
                lang: settings.language,
                onSettings: { ui.mode = .settings },
                onQuit: onQuit
            )
        case .stats:
            StatsView(
                settings: settings,
                stats: stats,
                onBack: { ui.mode = .settings },
                onView: { ui.mode = .statsData }
            )
        case .statsData:
            StatsDashboardView(
                stats: stats,
                settings: settings,
                onBack: { ui.mode = .stats }
            )
        }
    }
}

// MARK: - Context menu view

struct ContextMenuView: View {
    let lang: String
    let onSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            MenuRow(icon: "gearshape", label: tr("settings", lang), action: onSettings)
            Divider().padding(.vertical, 2)
            MenuRow(icon: "power", label: tr("quit", lang), action: onQuit)
        }
        .padding(6)
        .frame(width: 180)
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
    @State private var accent: Color? = nil

    var body: some View {
        let t = state.track
        Group {
            if t.isOff {
                VStack {
                    Text(tr("spotify_off", settings.language))
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
    let onOpenStats: () -> Void

    var body: some View {
        let lang = settings.language
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("settings", lang))
                .font(.system(size: 13, weight: .semibold))
            Divider()
            SettingsRow(label: tr("album_image", lang), value: $settings.showImage)
            SettingsRow(label: tr("song_name", lang), value: $settings.showTitle)
            SettingsRow(label: tr("artist", lang), value: $settings.showArtist)
            SettingsRow(label: tr("album", lang), value: $settings.showAlbum)
            SettingsRow(label: tr("volume_slider", lang), value: $settings.showVolume)
            SettingsRow(label: tr("progress_slider", lang), value: $settings.showProgress)
            Divider()
            SettingsRow(label: tr("vinyl_animation", lang), value: $settings.vinylEnabled)
            SettingsRow(label: tr("theme_from_art", lang), value: $settings.accentFromArt)
            Divider()
            SettingsRow(label: tr("toast_song_change", lang), value: $settings.toastEnabled)
            if settings.toastEnabled {
                HStack {
                    Text(tr("position", lang))
                    Spacer()
                    Picker("", selection: $settings.toastPosition) {
                        Text(tr("top_left", lang)).tag("topLeft")
                        Text(tr("top_right", lang)).tag("topRight")
                        Text(tr("bottom_left", lang)).tag("bottomLeft")
                        Text(tr("bottom_right", lang)).tag("bottomRight")
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 130)
                }
            }
            Divider()
            HStack {
                Text(tr("language", lang))
                Spacer()
                Picker("", selection: $settings.language) {
                    Text("English").tag("en")
                    Text("Español").tag("es")
                    Text("中文").tag("zh")
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 110)
            }
            Divider()
            NavRow(label: tr("stats", lang), action: onOpenStats)
        }
        .font(.system(size: 11))
        .padding(12)
        .frame(width: 240)
    }
}

struct NavRow: View {
    let label: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hover ? Color.primary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct StatsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var stats: StatsStore
    let onBack: () -> Void
    let onView: () -> Void

    var body: some View {
        let lang = settings.language
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                Text(tr("stats", lang))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            Divider()

            if !settings.statsAsked {
                firstTimePrompt(lang: lang)
            } else {
                SettingsRow(label: tr("enable_stats", lang), value: $settings.statsEnabled)
                if settings.statsEnabled {
                    Divider()
                    Text(tr("tracking", lang))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    SettingsRow(label: tr("play_count_song", lang), value: $settings.statsPlayCount)
                    SettingsRow(label: tr("skip_count_song", lang), value: $settings.statsSkipCount)
                    SettingsRow(label: tr("minutes_per_day", lang), value: $settings.statsDailyMinutes)
                    SettingsRow(label: tr("plays_per_artist", lang), value: $settings.statsArtistPlays)
                    Divider()
                    NavRow(label: tr("view_stats", lang), action: onView)
                    Divider()
                    Text(tr("data_local", lang))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Button(action: { stats.reset() }) {
                        Text(tr("clear_stats", lang))
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .font(.system(size: 11))
        .padding(12)
        .frame(width: 260)
    }

    private func firstTimePrompt(lang: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("enable_stats_q", lang))
                .font(.system(size: 12, weight: .semibold))
            Text(tr("stats_description", lang))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button(action: {
                    settings.statsEnabled = true
                    settings.statsAsked = true
                }) {
                    Text(tr("enable", lang))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.green))
                }
                .buttonStyle(.plain)
                Button(action: {
                    settings.statsEnabled = false
                    settings.statsAsked = true
                }) {
                    Text(tr("not_now", lang))
                        .font(.system(size: 11))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Toast

struct ToastView: View {
    let track: SpotifyTrack
    let lang: String

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
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                Text(tr("now_playing", lang))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
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
        .frame(width: 270)
    }
}

final class ToastController {
    private var panel: NSPanel?
    private var hosting: NSHostingController<ToastView>?
    private var hideWork: DispatchWorkItem?

    func show(track: SpotifyTrack, position: String, lang: String) {
        build(lang: lang)
        guard let panel, let hosting else { return }
        hosting.rootView = ToastView(track: track, lang: lang)
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

    private func build(lang: String) {
        if panel != nil { return }
        let h = NSHostingController(rootView: ToastView(track: .off, lang: lang))
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

// MARK: - Stats dashboard

struct StatsDashboardView: View {
    @ObservedObject var stats: StatsStore
    @ObservedObject var settings: AppSettings
    let onBack: () -> Void

    var body: some View {
        let lang = settings.language
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                Text(tr("your_stats", lang))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            Divider()

            if isEmpty {
                Text(tr("no_data", lang))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                summary(lang: lang)
                Divider()
                if !topTracks.isEmpty {
                    sectionTitle(tr("top_tracks", lang))
                    ForEach(Array(topTracks.enumerated()), id: \.offset) { idx, item in
                        rankRow(rank: idx + 1, title: item.0, value: "\(item.1)")
                    }
                    Divider()
                }
                if !topArtists.isEmpty {
                    sectionTitle(tr("top_artists", lang))
                    ForEach(Array(topArtists.enumerated()), id: \.offset) { idx, item in
                        rankRow(rank: idx + 1, title: item.0, value: "\(item.1)")
                    }
                    Divider()
                }
                if !last7.isEmpty {
                    sectionTitle(tr("last_7_days", lang))
                    dailyChart
                }
            }
        }
        .font(.system(size: 11))
        .padding(12)
        .frame(width: 300)
    }

    private var isEmpty: Bool {
        stats.data.plays.isEmpty &&
        stats.data.skips.isEmpty &&
        stats.data.artistPlays.isEmpty &&
        stats.data.dailyMinutes.isEmpty
    }

    private func summary(lang: String) -> some View {
        HStack(spacing: 12) {
            statCard(label: tr("plays", lang), value: "\(stats.data.plays.values.reduce(0,+))")
            statCard(label: tr("skips", lang), value: "\(stats.data.skips.values.reduce(0,+))")
            statCard(label: tr("minutes", lang), value: String(format: "%.0f", stats.data.dailyMinutes.values.reduce(0,+)))
        }
    }

    private func statCard(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.06)))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func rankRow(rank: Int, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text("\(rank).")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 18, alignment: .trailing)
            Text(title)
                .font(.system(size: 11))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var topTracks: [(String, Int)] {
        stats.data.plays.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }

    private var topArtists: [(String, Int)] {
        stats.data.artistPlays.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }

    private var last7: [(String, Double)] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { i -> (String, Double) in
            let d = cal.date(byAdding: .day, value: -i, to: today)!
            let key = fmt.string(from: d)
            return (key, stats.data.dailyMinutes[key] ?? 0)
        }
    }

    private var dailyChart: some View {
        let days = last7
        let maxVal = max(days.map { $0.1 }.max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, entry in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green.opacity(0.8))
                        .frame(height: max(2, CGFloat(entry.1 / maxVal) * 60))
                    Text(shortDay(entry.0))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 78)
    }

    private func shortDay(_ iso: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: iso) else { return "" }
        let out = DateFormatter()
        out.dateFormat = "E"
        return String(out.string(from: d).prefix(2))
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
    private let stats = StatsStore()
    private let toast = ToastController()
    private var refreshTimer: Timer?
    private var tickTimer: Timer?
    private var outsideClickMonitor: Any?
    private var modeCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        stats.settings = settings

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "♪ —"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleClick(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        hosting = NSHostingController(rootView: RootView(
            state: state,
            settings: settings,
            ui: ui,
            stats: stats,
            onQuit: { NSApp.terminate(nil) }
        ))

        state.onTrackChange = { [weak self] track in
            guard let self else { return }
            self.stats.trackChanged(to: track)
            if self.settings.toastEnabled {
                self.toast.show(track: track, position: self.settings.toastPosition, lang: self.settings.language)
            }
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
            guard let self else { return }
            self.state.tickPosition()
            self.stats.tick(self.state.track)
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
