import AppKit
import SwiftUI
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreAudio
import Darwin

// MARK: - Model

enum MediaKind: String, Equatable { case spotify, music, other }

struct SpotifyTrack: Equatable {
    var name: String
    var artist: String
    var album: String
    var artUrl: String
    var artworkData: Data?
    var isPlaying: Bool
    var shuffling: Bool
    var repeating: Bool
    var volume: Int
    var position: Double
    var duration: Double
    var isOff: Bool
    var kind: MediaKind
    var appName: String
    var bundleID: String

    static let off = SpotifyTrack(
        name: "", artist: "", album: "", artUrl: "", artworkData: nil,
        isPlaying: false, shuffling: false, repeating: false,
        volume: 50, position: 0, duration: 0, isOff: true,
        kind: .spotify, appName: "Spotify", bundleID: "com.spotify.client"
    )

    static let musicOff = SpotifyTrack(
        name: "", artist: "", album: "", artUrl: "", artworkData: nil,
        isPlaying: false, shuffling: false, repeating: false,
        volume: 50, position: 0, duration: 0, isOff: true,
        kind: .music, appName: "Music", bundleID: "com.apple.Music"
    )

    var isSpotify: Bool { kind == .spotify }
    var isMusic: Bool { kind == .music }

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
    @Published var preferredSourceBundleID: String { didSet { save() } }
    @Published var onboardingCompleted: Bool { didSet { save() } }

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
        preferredSourceBundleID = d.string(forKey: "preferredSourceBundleID") ?? ""
        onboardingCompleted = d.object(forKey: "onboardingCompleted") as? Bool ?? false
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
        d.set(preferredSourceBundleID, forKey: "preferredSourceBundleID")
        d.set(onboardingCompleted, forKey: "onboardingCompleted")
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
        "open_music": [
            "en": "Open Apple Music",
            "es": "Abrir Apple Music",
            "zh": "打开 Apple Music"
        ],
        "setup_title": [
            "en": "Welcome to NowBar",
            "es": "Bienvenido a NowBar",
            "zh": "欢迎使用 NowBar"
        ],
        "setup_subtitle": [
            "en": "To control audio in browsers, enable \"Allow JavaScript from Apple Events\" once per browser.",
            "es": "Para controlar audio en navegadores, activa \"Permitir JavaScript de Apple Events\" una vez por navegador.",
            "zh": "要控制浏览器中的音频,每个浏览器只需启用一次“允许 Apple 事件的 JavaScript”。"
        ],
        "setup_instruction_chromium": [
            "en": "Menu → View → Developer → Allow JavaScript from Apple Events",
            "es": "Menú → Ver → Desarrollador → Permitir JavaScript de eventos de Apple",
            "zh": "菜单 → 查看 → 开发者 → 允许来自 Apple 事件的 JavaScript"
        ],
        "setup_instruction_safari": [
            "en": "Settings → Advanced → Show Develop menu, then Develop → Allow JavaScript from Apple Events",
            "es": "Ajustes → Avanzado → Mostrar menú Desarrollar, luego Desarrollar → Permitir JavaScript de Apple Events",
            "zh": "设置 → 高级 → 显示开发菜单,然后 开发 → 允许来自 Apple 事件的 JavaScript"
        ],
        "setup_open_browser": [
            "en": "Open",
            "es": "Abrir",
            "zh": "打开"
        ],
        "setup_status_configured": [
            "en": "Configured",
            "es": "Configurado",
            "zh": "已配置"
        ],
        "setup_status_unconfigured": [
            "en": "Needs setup",
            "es": "Requiere configuración",
            "zh": "需要设置"
        ],
        "setup_status_not_running": [
            "en": "Not running",
            "es": "No abierto",
            "zh": "未运行"
        ],
        "setup_status_not_installed": [
            "en": "Not installed",
            "es": "No instalado",
            "zh": "未安装"
        ],
        "setup_recheck": [
            "en": "Re-check",
            "es": "Verificar de nuevo",
            "zh": "重新检查"
        ],
        "setup_done": [
            "en": "Done",
            "es": "Listo",
            "zh": "完成"
        ],
        "setup_skip": [
            "en": "Skip",
            "es": "Omitir",
            "zh": "跳过"
        ],
        "setup_banner_title": [
            "en": "Set up browsers",
            "es": "Configurar navegadores",
            "zh": "设置浏览器"
        ],
        "setup_banner_subtitle": [
            "en": "Enable JavaScript from Apple Events",
            "es": "Habilita JavaScript de Apple Events",
            "zh": "启用来自 Apple 事件的 JavaScript"
        ],
        "nothing_playing": [
            "en": "Nothing is playing",
            "es": "No hay música reproduciéndose",
            "zh": "没有正在播放的音乐"
        ],
        "open_spotify": [
            "en": "Open Spotify",
            "es": "Abrir Spotify",
            "zh": "打开 Spotify"
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
        "stats": ["en": "Spotify Stats", "es": "Estadísticas de Spotify", "zh": "Spotify 统计"],
        "view_stats": ["en": "View Spotify stats", "es": "Ver estadísticas de Spotify", "zh": "查看 Spotify 统计"],
        "enable_stats": ["en": "Enable Spotify stats", "es": "Activar estadísticas de Spotify", "zh": "启用 Spotify 统计"],
        "clear_stats": ["en": "Clear all stats", "es": "Borrar todas", "zh": "清除所有"],
        "data_local": [
            "en": "Data stored locally only",
            "es": "Los datos se guardan solo localmente",
            "zh": "数据仅存于本地"
        ],
        "enable_stats_q": [
            "en": "Enable Spotify stats?",
            "es": "¿Activar estadísticas de Spotify?",
            "zh": "启用 Spotify 统计？"
        ],
        "stats_description": [
            "en": "Track Spotify play counts, skips, minutes per day, and per-artist plays. Data stays on this Mac — nothing leaves the device.",
            "es": "Registra reproducciones, saltos, minutos por día y reproducciones por artista de Spotify. Los datos quedan en este Mac — nada sale del dispositivo.",
            "zh": "记录 Spotify 播放次数、跳过、每日分钟数和每位艺术家的播放数。数据仅留在本机 — 不发送到任何地方。"
        ],
        "enable": ["en": "Enable", "es": "Activar", "zh": "启用"],
        "not_now": ["en": "Not now", "es": "Ahora no", "zh": "暂不"],
        "play_count_song": ["en": "Play count per song", "es": "Reproducciones por canción", "zh": "每首播放次数"],
        "skip_count_song": ["en": "Skip count per song", "es": "Saltos por canción", "zh": "每首跳过次数"],
        "minutes_per_day": ["en": "Minutes per day", "es": "Minutos por día", "zh": "每日分钟"],
        "plays_per_artist": ["en": "Plays per artist", "es": "Reproducciones por artista", "zh": "每位艺术家播放次数"],
        "tracking": ["en": "Tracking", "es": "Registrando", "zh": "记录项"],
        "your_stats": ["en": "Your Spotify Stats", "es": "Tus estadísticas de Spotify", "zh": "你的 Spotify 统计"],
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
        "setup_browsers_menu": ["en": "Set up browsers", "es": "Configurar navegadores", "zh": "设置浏览器"],
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
        guard let s = settings, s.statsEnabled, !t.isOff, t.isPlaying, t.isSpotify else { return }
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
        guard t.isOff || t.isSpotify else { return }
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
            artworkData: nil,
            isPlaying: parts[4] == "playing",
            shuffling: parts[5] == "true",
            repeating: parts[6] == "true",
            volume: Int(parts[7]) ?? 50,
            position: parseNumber(parts[8]),
            duration: parseNumber(parts[9]),
            isOff: false,
            kind: .spotify,
            appName: "Spotify",
            bundleID: "com.spotify.client"
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

// MARK: - Apple Music AppleScript bridge

enum MusicAPI {
    static func currentTrack() -> SpotifyTrack {
        let script = """
        tell application "Music"
          if it is running then
            try
              if player state is stopped then return "off"
              set t to name of current track
              set a to artist of current track
              set al to album of current track
              set s to player state as string
              set sh to (shuffle enabled) as string
              set rp to (song repeat as string)
              set v to sound volume as string
              set p to (player position) as string
              set d to (duration of current track) as string
              return t & "§" & a & "§" & al & "§" & s & "§" & sh & "§" & rp & "§" & v & "§" & p & "§" & d
            on error
              return "off"
            end try
          else
            return "off"
          end if
        end tell
        """
        guard let raw = run(script), raw != "off" else { return .musicOff }
        let parts = raw.components(separatedBy: "§")
        guard parts.count == 9 else { return .musicOff }
        return SpotifyTrack(
            name: parts[0],
            artist: parts[1],
            album: parts[2],
            artUrl: "",
            artworkData: nil,
            isPlaying: parts[3] == "playing",
            shuffling: parts[4] == "true",
            repeating: parts[5] != "off",
            volume: Int(parts[6]) ?? 50,
            position: parseNumber(parts[7]),
            duration: parseNumber(parts[8]),
            isOff: false,
            kind: .music,
            appName: "Music",
            bundleID: "com.apple.Music"
        )
    }

    private static func parseNumber(_ s: String) -> Double {
        let normalized = s.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    static func setVolume(_ value: Int) {
        _ = run("tell application \"Music\" to set sound volume to \(value)")
    }

    static func toggleShuffle(_ on: Bool) {
        _ = run("tell application \"Music\" to set shuffle enabled to \(on ? "true" : "false")")
    }

    static func toggleRepeat(_ on: Bool) {
        let value = on ? "all" : "off"
        _ = run("tell application \"Music\" to set song repeat to \(value)")
    }

    static func seek(_ seconds: Double) {
        _ = run("tell application \"Music\" to set player position to \(seconds)")
    }

    static func perform(_ action: String) {
        _ = run("tell application \"Music\" to \(action)")
    }

    static func reveal() {
        _ = run("""
        tell application "Music"
          activate
          try
            reveal current track
          end try
        end tell
        """)
    }

    @discardableResult
    private static func run(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        return result.stringValue
    }
}

// MARK: - Browser setup detection

enum BrowserSetup {
    enum Status: Equatable { case configured, unconfigured, notRunning, notInstalled }

    static func status(for entry: (bundleID: String, appName: String, dialect: BrowserJS.Dialect)) -> Status {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.bundleID) != nil else {
            return .notInstalled
        }
        guard NSRunningApplication.runningApplications(withBundleIdentifier: entry.bundleID).first != nil else {
            return .notRunning
        }
        let probe: String
        switch entry.dialect {
        case .chromium:
            probe = """
            tell application "\(entry.appName)"
                try
                    repeat with w in windows
                        try
                            set t to active tab of w
                            set r to (execute t javascript "'nb_ok'")
                            if r is "nb_ok" then return "ok"
                        end try
                    end repeat
                end try
                return "nok"
            end tell
            """
        case .safari:
            probe = """
            tell application "Safari"
                try
                    repeat with w in windows
                        try
                            set t to current tab of w
                            set r to (do JavaScript "'nb_ok'" in t)
                            if r is "nb_ok" then return "ok"
                        end try
                    end repeat
                end try
                return "nok"
            end tell
            """
        }
        return runProbe(probe) == "ok" ? .configured : .unconfigured
    }

    static func allStatuses() -> [(entry: (bundleID: String, appName: String, dialect: BrowserJS.Dialect), status: Status)] {
        BrowserJS.supported.map { entry in (entry, status(for: entry)) }
    }

    static func anyUnconfiguredRunning() -> Bool {
        allStatuses().contains { $0.status == .unconfigured }
    }

    static func activate(_ entry: (bundleID: String, appName: String, dialect: BrowserJS.Dialect)) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.bundleID) {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: cfg, completionHandler: nil)
        }
    }

    private static func runProbe(_ source: String, timeout: TimeInterval = 2.0) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", source]
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        do { try proc.run() } catch { return nil }
        let deadline = Date().addingTimeInterval(timeout)
        while proc.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        if proc.isRunning {
            proc.terminate()
            Thread.sleep(forTimeInterval: 0.1)
            if proc.isRunning { kill(proc.processIdentifier, SIGKILL) }
            return nil
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - iTunes Search artwork lookup

enum MusicArtwork {
    private static var cache: [String: String] = [:]
    private static let queue = DispatchQueue(label: "NowBar.MusicArtwork", attributes: .concurrent)

    static func cached(artist: String, name: String) -> String? {
        queue.sync { cache[key(artist, name)] }
    }

    static func lookup(artist: String, name: String, completion: @escaping (String?) -> Void) {
        let k = key(artist, name)
        if let hit = queue.sync(execute: { cache[k] }) {
            DispatchQueue.main.async { completion(hit) }
            return
        }
        let term = "\(artist) \(name)"
        guard let q = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(q)&entity=musicTrack&limit=1")
        else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            var result: String? = nil
            if let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let first = results.first,
               let u100 = first["artworkUrl100"] as? String {
                result = u100.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            }
            if let result {
                queue.async(flags: .barrier) { cache[k] = result }
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    private static func key(_ artist: String, _ name: String) -> String { "\(artist)|\(name)" }
}

// MARK: - Browser JS (Chromium AppleScript)

enum BrowserJS {
    enum Dialect { case chromium, safari }

    static let supported: [(bundleID: String, appName: String, dialect: Dialect)] = [
        ("com.brave.Browser", "Brave Browser", .chromium),
        ("com.google.Chrome", "Google Chrome", .chromium),
        ("com.microsoft.edgemac", "Microsoft Edge", .chromium),
        ("company.thebrowser.Browser", "Arc", .chromium),
        ("com.operasoftware.Opera", "Opera", .chromium),
        ("com.vivaldi.Vivaldi", "Vivaldi", .chromium),
        ("com.apple.Safari", "Safari", .safari)
    ]

    static func autoEnableJavaScriptFromAppleEvents() {
        let cfg: [(bundle: String, keys: [(String, String)])] = [
            ("com.brave.Browser", [("AllowJavaScriptFromAppleEvents", "-bool"), ("DeveloperToolsAvailability", "-int")]),
            ("com.google.Chrome", [("AllowJavaScriptFromAppleEvents", "-bool")]),
            ("com.microsoft.edgemac", [("AllowJavaScriptFromAppleEvents", "-bool")]),
            ("company.thebrowser.Browser", [("AllowJavaScriptFromAppleEvents", "-bool")]),
            ("com.operasoftware.Opera", [("AllowJavaScriptFromAppleEvents", "-bool")]),
            ("com.vivaldi.Vivaldi", [("AllowJavaScriptFromAppleEvents", "-bool")]),
            ("com.apple.Safari", [
                ("IncludeDevelopMenu", "-bool"),
                ("WebKitDeveloperExtras", "-bool"),
                ("WebKitPreferences.developerExtrasEnabled", "-bool"),
                ("AllowJavaScriptFromAppleEvents", "-bool")
            ])
        ]
        for entry in cfg {
            for (key, type) in entry.keys {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
                let value = type == "-int" ? "1" : "true"
                proc.arguments = ["write", entry.bundle, key, type, value]
                proc.standardOutput = Pipe()
                proc.standardError = Pipe()
                try? proc.run()
                proc.waitUntilExit()
            }
        }
        NSLog("NowBar BrowserJS: autoEnable defaults write done")
    }

    struct Snapshot {
        var bundleID: String
        var appName: String
        var title: String
        var artist: String
        var artUrl: String
        var isPlaying: Bool
        var position: Double
        var duration: Double
    }

    static func firstAudible() -> Snapshot? {
        NSLog("NowBar BrowserJS: firstAudible start")
        for entry in supported {
            guard NSRunningApplication.runningApplications(withBundleIdentifier: entry.bundleID).first != nil
            else { continue }
            if let s = snapshot(entry: entry) {
                NSLog("NowBar BrowserJS: match %@ title=%@ playing=%@", entry.bundleID, s.title, s.isPlaying ? "yes":"no")
                return s
            } else {
                NSLog("NowBar BrowserJS: %@ no audible tab", entry.bundleID)
            }
        }
        return nil
    }

    private static let separator = "@@~~@@"

    private static let mediaHostsClause = #"{"youtube.com", "music.youtube.com", "soundcloud.com", "spotify.com", "twitch.tv", "vimeo.com", "netflix.com", "bandcamp.com", "mixcloud.com", "deezer.com", "tidal.com", "apple.com/music"}"#

    private static func snapshotJS(sep: String) -> String {
        return """
        (function(){var m=document.querySelector('video,audio');if(!m)return '';\
        var md=navigator.mediaSession&&navigator.mediaSession.metadata;\
        var ti=(md&&md.title)||document.title||'';\
        var ar=(md&&md.artist)||'';\
        var aw=md&&md.artwork&&md.artwork[0]?md.artwork[0].src:'';\
        var S='\(sep)';\
        return (m.paused?'0':'1')+S+m.currentTime+S+(m.duration||0)+S+ti+S+ar+S+aw;})()
        """
    }

    private static func snapshot(entry: (bundleID: String, appName: String, dialect: Dialect)) -> Snapshot? {
        let sep = separator
        let js = snapshotJS(sep: sep)
        let escaped = js.replacingOccurrences(of: "\"", with: "\\\"")
        let script: String
        switch entry.dialect {
        case .chromium:
            script = """
            tell application "\(entry.appName)"
                if it is not running then return ""
                set mediaHosts to \(mediaHostsClause)
                repeat with w in windows
                    try
                        set t to active tab of w
                        set u to URL of t as string
                        repeat with h in mediaHosts
                            if u contains h then
                                set r to (execute t javascript "\(escaped)")
                                if r is not "" and r is not missing value then return r as string
                                exit repeat
                            end if
                        end repeat
                    end try
                end repeat
                set scanned to 0
                repeat with w in windows
                    repeat with t in tabs of w
                        if scanned >= 40 then exit repeat
                        set scanned to scanned + 1
                        try
                            set u to URL of t as string
                            repeat with h in mediaHosts
                                if u contains h then
                                    set r to (execute t javascript "\(escaped)")
                                    if r is not "" and r is not missing value then return r as string
                                    exit repeat
                                end if
                            end repeat
                        end try
                    end repeat
                    if scanned >= 40 then exit repeat
                end repeat
                return ""
            end tell
            """
        case .safari:
            script = """
            tell application "\(entry.appName)"
                if it is not running then return ""
                set mediaHosts to \(mediaHostsClause)
                repeat with w in windows
                    try
                        set t to current tab of w
                        set u to URL of t as string
                        repeat with h in mediaHosts
                            if u contains h then
                                set r to (do JavaScript "\(escaped)" in t)
                                if r is not "" and r is not missing value then return r as string
                                exit repeat
                            end if
                        end repeat
                    end try
                end repeat
                set scanned to 0
                repeat with w in windows
                    repeat with t in tabs of w
                        if scanned >= 40 then exit repeat
                        set scanned to scanned + 1
                        try
                            set u to URL of t as string
                            repeat with h in mediaHosts
                                if u contains h then
                                    set r to (do JavaScript "\(escaped)" in t)
                                    if r is not "" and r is not missing value then return r as string
                                    exit repeat
                                end if
                            end repeat
                        end try
                    end repeat
                    if scanned >= 40 then exit repeat
                end repeat
                return ""
            end tell
            """
        }
        guard let raw = runAppleScript(script), !raw.isEmpty else {
            NSLog("NowBar BrowserJS: %@ raw empty", entry.bundleID)
            return nil
        }
        NSLog("NowBar BrowserJS: %@ raw=%@", entry.bundleID, raw)
        let parts = raw.components(separatedBy: sep)
        guard parts.count >= 6 else { return nil }
        let playing = parts[0] == "1"
        let pos = Double(parts[1]) ?? 0
        let dur = Double(parts[2]) ?? 0
        return Snapshot(
            bundleID: entry.bundleID, appName: entry.appName,
            title: parts[3], artist: parts[4], artUrl: parts[5],
            isPlaying: playing, position: pos, duration: dur
        )
    }

    static func togglePlay(bundleID: String) {
        runJS(bundleID: bundleID,
              js: "var m=document.querySelector('video,audio');if(m){m.paused?m.play():m.pause()}")
    }

    static func next(bundleID: String) {
        let js = "var sels=['.ytp-next-button','tp-yt-paper-icon-button.next-button','button[data-testid=control-button-skip-forward]','button[aria-label*=Next]','button[aria-label*=next]','button[aria-label*=Siguiente]','button[aria-label*=siguiente]','button[aria-label*=Suivant]','button[aria-label*=Nächster]'];for(var i=0;i<sels.length;i++){try{var b=document.querySelector(sels[i]);if(b){b.click();break}}catch(e){}}"
        runJS(bundleID: bundleID, js: js)
    }

    static func previous(bundleID: String) {
        let js = "var sels=['.ytp-prev-button','tp-yt-paper-icon-button.previous-button','button[data-testid=control-button-skip-back]','button[aria-label*=Previous]','button[aria-label*=previous]','button[aria-label*=Anterior]','button[aria-label*=anterior]','button[aria-label*=Précédent]','button[aria-label*=Vorheriger]'];var clicked=false;for(var i=0;i<sels.length;i++){try{var b=document.querySelector(sels[i]);if(b){b.click();clicked=true;break}}catch(e){}}if(!clicked){var m=document.querySelector('video,audio');if(m)m.currentTime=0}"
        runJS(bundleID: bundleID, js: js)
    }

    static func seek(bundleID: String, seconds: Double) {
        runJS(bundleID: bundleID,
              js: "var m=document.querySelector('video,audio');if(m)m.currentTime=\(seconds)")
    }

    private static func runJS(bundleID: String, js: String) {
        guard let entry = supported.first(where: { $0.bundleID == bundleID }) else { return }
        let escaped = js.replacingOccurrences(of: "\"", with: "\\\"")
        let script: String
        switch entry.dialect {
        case .chromium:
            script = """
            tell application "\(entry.appName)"
                if it is not running then return
                set mediaHosts to \(mediaHostsClause)
                repeat with w in windows
                    try
                        set t to active tab of w
                        set u to URL of t as string
                        repeat with h in mediaHosts
                            if u contains h then
                                try
                                    execute t javascript "\(escaped)"
                                end try
                                return
                            end if
                        end repeat
                    end try
                end repeat
                set scanned to 0
                repeat with w in windows
                    repeat with t in tabs of w
                        if scanned >= 40 then exit repeat
                        set scanned to scanned + 1
                        try
                            set u to URL of t as string
                            repeat with h in mediaHosts
                                if u contains h then
                                    try
                                        execute t javascript "\(escaped)"
                                    end try
                                    return
                                end if
                            end repeat
                        end try
                    end repeat
                    if scanned >= 40 then exit repeat
                end repeat
            end tell
            """
        case .safari:
            script = """
            tell application "\(entry.appName)"
                if it is not running then return
                set mediaHosts to \(mediaHostsClause)
                repeat with w in windows
                    try
                        set t to current tab of w
                        set u to URL of t as string
                        repeat with h in mediaHosts
                            if u contains h then
                                try
                                    do JavaScript "\(escaped)" in t
                                end try
                                return
                            end if
                        end repeat
                    end try
                end repeat
                set scanned to 0
                repeat with w in windows
                    repeat with t in tabs of w
                        if scanned >= 40 then exit repeat
                        set scanned to scanned + 1
                        try
                            set u to URL of t as string
                            repeat with h in mediaHosts
                                if u contains h then
                                    try
                                        do JavaScript "\(escaped)" in t
                                    end try
                                    return
                                end if
                            end repeat
                        end try
                    end repeat
                    if scanned >= 40 then exit repeat
                end repeat
            end tell
            """
        }
        _ = runAppleScript(script)
    }

    private static func runAppleScript(_ source: String, timeout: TimeInterval = 4.0) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", source]
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        do {
            try proc.run()
        } catch {
            NSLog("NowBar BrowserJS proc err: %@", error.localizedDescription)
            return nil
        }
        let deadline = Date().addingTimeInterval(timeout)
        while proc.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if proc.isRunning {
            proc.terminate()
            Thread.sleep(forTimeInterval: 0.1)
            if proc.isRunning { kill(proc.processIdentifier, SIGKILL) }
            NSLog("NowBar BrowserJS: osascript timeout, killed")
            return nil
        }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        if proc.terminationStatus != 0,
           let msg = String(data: errData, encoding: .utf8), !msg.isEmpty {
            NSLog("NowBar BrowserJS err: %@", msg)
            return nil
        }
        return String(data: outData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Process helpers

@_silgen_name("responsibility_get_pid_responsible_for_pid")
private func responsibility_get_pid_responsible_for_pid(_ pid: pid_t) -> pid_t

enum ProcInspect {
    static func path(forPID pid: pid_t) -> String? {
        let bufSize = 4096
        let buf = UnsafeMutablePointer<CChar>.allocate(capacity: bufSize)
        defer { buf.deallocate() }
        let len = proc_pidpath(pid, buf, UInt32(bufSize))
        guard len > 0 else { return nil }
        return String(cString: buf)
    }

    static func outermostAppBundleID(forPID pid: pid_t) -> String? {
        guard let p = path(forPID: pid) else { return nil }
        let parts = p.split(separator: "/", omittingEmptySubsequences: true)
        var accum = ""
        for part in parts {
            accum += "/" + part
            if part.hasSuffix(".app") {
                return Bundle(path: accum)?.bundleIdentifier
            }
        }
        return nil
    }

    static func resolveBundleID(forAudioPID pid: pid_t) -> String? {
        if let app = NSRunningApplication(processIdentifier: pid),
           let bid = app.bundleIdentifier {
            return bid
        }
        if let bid = outermostAppBundleID(forPID: pid) {
            return bid
        }
        let rp = responsibility_get_pid_responsible_for_pid(pid)
        if rp > 0, rp != pid,
           let app = NSRunningApplication(processIdentifier: rp),
           let bid = app.bundleIdentifier {
            return bid
        }
        return nil
    }
}

// MARK: - Audio activity (CoreAudio HAL)

enum AudioActivity {
    private static let kProcessObjectList: AudioObjectPropertySelector = 0x70727323 // 'prs#'
    private static let kProcessPID: AudioObjectPropertySelector = 0x70706964 // 'ppid'
    private static let kProcessIsRunningOutput: AudioObjectPropertySelector = 0x70726F20 // 'pro '

    static func playingProcessPIDs() -> Set<pid_t> {
        var addr = AudioObjectPropertyAddress(
            mSelector: kProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size
        )
        guard status == noErr, size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var objects = [AudioObjectID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &objects
        )
        guard status == noErr else { return [] }

        var active: Set<pid_t> = []
        for obj in objects {
            var rAddr = AudioObjectPropertyAddress(
                mSelector: kProcessIsRunningOutput,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var running: UInt32 = 0
            var rSize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
            let rStat = AudioObjectGetPropertyData(obj, &rAddr, 0, nil, &rSize, &running)
            guard rStat == noErr, running != 0 else { continue }

            var pAddr = AudioObjectPropertyAddress(
                mSelector: kProcessPID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var pid: pid_t = 0
            var pSize: UInt32 = UInt32(MemoryLayout<pid_t>.size)
            let pStat = AudioObjectGetPropertyData(obj, &pAddr, 0, nil, &pSize, &pid)
            if pStat == noErr, pid > 0 { active.insert(pid) }
        }
        return active
    }
}

// MARK: - System volume

enum SystemVolume {
    static func get() -> Int {
        var err: NSDictionary?
        guard let script = NSAppleScript(source: "output volume of (get volume settings)")
        else { return 50 }
        let r = script.executeAndReturnError(&err)
        let v = Int(r.int32Value)
        return v >= 0 ? v : 50
    }
    static func set(_ v: Int) {
        let clamped = max(0, min(100, v))
        var err: NSDictionary?
        let script = NSAppleScript(source: "set volume output volume \(clamped)")
        script?.executeAndReturnError(&err)
    }
}

// MARK: - Media app detector

enum MediaAppDetector {
    static let knownBundles: [(String, String)] = [
        ("com.apple.Music", "Music"),
        ("com.apple.podcasts", "Podcasts"),
        ("com.apple.Safari", "Safari"),
        ("com.google.Chrome", "Chrome"),
        ("com.brave.Browser", "Brave"),
        ("com.microsoft.edgemac", "Edge"),
        ("org.mozilla.firefox", "Firefox"),
        ("company.thebrowser.Browser", "Arc"),
        ("org.videolan.vlc", "VLC"),
        ("com.colliderli.iina", "IINA"),
        ("com.apple.QuickTimePlayerX", "QuickTime")
    ]

    static func running() -> [SpotifyTrack] {
        knownBundles.compactMap { bid, fallback in
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bid).first
            else { return nil }
            let name = app.localizedName ?? fallback
            return SpotifyTrack(
                name: name, artist: "", album: "", artUrl: "", artworkData: nil,
                isPlaying: false, shuffling: false, repeating: false,
                volume: 50, position: 0, duration: 0, isOff: false,
                kind: .other, appName: name, bundleID: bid
            )
        }
    }
}

// MARK: - Media keys

enum MediaKey {
    static let play: Int32 = 16
    static let next: Int32 = 17
    static let prev: Int32 = 18

    @discardableResult
    static func ensureAccessibility(prompt: Bool) -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    static func post(_ keyCode: Int32) {
        let ax = ensureAccessibility(prompt: true)
        NSLog("NowBar MediaKey: post keyCode=%d ax=%@", keyCode, ax ? "true" : "false")
        if !ax { return }
        postEvent(keyCode: keyCode, down: true)
        postEvent(keyCode: keyCode, down: false)
    }

    private static func postEvent(keyCode: Int32, down: Bool) {
        let flags: Int = down ? 0xa00 : 0xb00
        let data1 = (Int(keyCode) << 16) | flags
        guard let ev = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        ) else {
            NSLog("NowBar MediaKey: NSEvent nil")
            return
        }
        guard let cg = ev.cgEvent else {
            NSLog("NowBar MediaKey: cgEvent nil down=%@", down ? "true" : "false")
            return
        }
        cg.post(tap: .cghidEventTap)
        NSLog("NowBar MediaKey: posted down=%@", down ? "true" : "false")
    }
}

// MARK: - MediaRemote bridge

struct MRInfo {
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var position: Double
    var isPlaying: Bool
    var artwork: Data?
    var bundleID: String
    var appName: String
}

final class MediaRemoteBridge {
    static let shared = MediaRemoteBridge()

    private typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias GetPIDFn = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
    private typealias SendCommandFn = @convention(c) (Int32, NSDictionary?) -> Bool
    private typealias RegisterFn = @convention(c) (DispatchQueue) -> Void
    private typealias SetElapsedFn = @convention(c) (Double) -> Void

    private let getInfo: GetInfoFn?
    private let getPID: GetPIDFn?
    private let sendCommand: SendCommandFn?
    private let setElapsed: SetElapsedFn?

    private init() {
        let url = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        guard let bundle = CFBundleCreate(nil, url as CFURL) else {
            getInfo = nil; getPID = nil; sendCommand = nil; setElapsed = nil
            return
        }
        func load<T>(_ name: String) -> T? {
            guard let ptr = CFBundleGetFunctionPointerForName(bundle, name as CFString) else { return nil }
            return unsafeBitCast(ptr, to: T.self)
        }
        getInfo = load("MRMediaRemoteGetNowPlayingInfo")
        getPID = load("MRMediaRemoteGetNowPlayingApplicationPID")
        sendCommand = load("MRMediaRemoteSendCommand")
        setElapsed = load("MRMediaRemoteSetElapsedTime")

        if let register: RegisterFn = load("MRMediaRemoteRegisterForNowPlayingNotifications") {
            register(.main)
        }
    }

    func fetch(_ completion: @escaping (MRInfo?) -> Void) {
        guard let getInfo, let getPID else {
            NSLog("NowBar MR: symbols missing")
            completion(nil); return
        }
        var info: [String: Any]?
        var pid: Int32 = 0
        let group = DispatchGroup()
        group.enter()
        getInfo(.main) { dict in
            info = dict
            group.leave()
        }
        group.enter()
        getPID(.main) { p in
            pid = p
            group.leave()
        }
        group.notify(queue: .main) {
            let dict = info ?? [:]
            let app = pid > 0 ? NSRunningApplication(processIdentifier: pid) : nil
            NSLog("NowBar MR: pid=%d bid=%@ dictKeys=%d",
                  pid, app?.bundleIdentifier ?? "nil", dict.count)
            completion(Self.build(from: dict, pid: pid))
        }
    }

    func nowPlayingBundleID(_ completion: @escaping (String?) -> Void) {
        guard let getPID else { completion(nil); return }
        getPID(.main) { pid in
            let bid = pid > 0 ? NSRunningApplication(processIdentifier: pid)?.bundleIdentifier : nil
            completion(bid)
        }
    }

    @discardableResult
    func send(_ command: Int32) -> Bool {
        let ok = sendCommand?(command, nil) ?? false
        NSLog("NowBar MR send: cmd=%d ok=%@", command, ok ? "true" : "false")
        return ok
    }

    func seek(_ seconds: Double) {
        setElapsed?(seconds)
    }

    private static func build(from info: [String: Any], pid: Int32) -> MRInfo? {
        let app = pid > 0 ? NSRunningApplication(processIdentifier: pid) : nil
        let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
        let hasInfo = !info.isEmpty
        let hasApp = app != nil && (app?.bundleIdentifier ?? "").isEmpty == false
        if !hasInfo && !hasApp { return nil }
        let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
        let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
        let duration = (info["kMRMediaRemoteNowPlayingInfoDuration"] as? NSNumber)?.doubleValue ?? 0
        let position = (info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? NSNumber)?.doubleValue ?? 0
        let rate = (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue ?? 0
        let art = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
        let appName = app?.localizedName ?? "Media"
        let fallbackTitle = title.isEmpty ? appName : title
        return MRInfo(
            title: fallbackTitle, artist: artist, album: album,
            duration: duration, position: position,
            isPlaying: hasInfo ? rate > 0 : true,
            artwork: art,
            bundleID: app?.bundleIdentifier ?? "",
            appName: appName
        )
    }
}

extension SpotifyTrack {
    static func fromMR(_ info: MRInfo) -> SpotifyTrack {
        SpotifyTrack(
            name: info.title, artist: info.artist, album: info.album,
            artUrl: "", artworkData: info.artwork,
            isPlaying: info.isPlaying,
            shuffling: false, repeating: false,
            volume: 50, position: info.position, duration: info.duration,
            isOff: false,
            kind: .other, appName: info.appName, bundleID: info.bundleID
        )
    }
}

enum MRCommand {
    static let play: Int32 = 0
    static let pause: Int32 = 1
    static let togglePlayPause: Int32 = 2
    static let nextTrack: Int32 = 4
    static let previousTrack: Int32 = 5
}

// MARK: - Shared state

final class SpotifyState: ObservableObject {
    @Published var track: SpotifyTrack = .off
    @Published private(set) var available: [SpotifyTrack] = []
    private var spotifyTrack: SpotifyTrack = .off
    private var musicTrack: SpotifyTrack = .musicOff
    weak var settings: AppSettings?
    var onTrackChange: ((SpotifyTrack) -> Void)?
    private var lastKey: String = ""

    func refresh() {
        spotifyTrack = SpotifyAPI.currentTrack()
        var mt = MusicAPI.currentTrack()
        if !mt.isOff, let cached = MusicArtwork.cached(artist: mt.artist, name: mt.name) {
            mt.artUrl = cached
        }
        musicTrack = mt
        recompute()

        if !mt.isOff && mt.artUrl.isEmpty {
            let artist = mt.artist, name = mt.name
            MusicArtwork.lookup(artist: artist, name: name) { [weak self] url in
                guard let self, let url else { return }
                if self.musicTrack.artist == artist && self.musicTrack.name == name {
                    self.musicTrack.artUrl = url
                    self.recompute()
                }
            }
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let snap = BrowserJS.firstAudible()
            let sysVol = SystemVolume.get()
            DispatchQueue.main.async {
                if let snap {
                    let sticky = self.otherTracks.contains { $0.bundleID == snap.bundleID }
                    if snap.isPlaying || sticky {
                        let name = snap.title.isEmpty ? snap.appName : snap.title
                        self.otherTracks = [SpotifyTrack(
                            name: name, artist: snap.artist, album: "",
                            artUrl: snap.artUrl, artworkData: nil,
                            isPlaying: snap.isPlaying, shuffling: false, repeating: false,
                            volume: sysVol, position: snap.position, duration: snap.duration,
                            isOff: false, kind: .other, appName: snap.appName, bundleID: snap.bundleID
                        )]
                    } else {
                        self.otherTracks = []
                    }
                } else {
                    self.otherTracks = []
                }
                self.recompute()
            }
        }
    }

    func optimisticTogglePlaying(for t: SpotifyTrack) {
        guard !t.isSpotify && !t.isMusic else { return }
        if let idx = otherTracks.firstIndex(where: { $0.bundleID == t.bundleID }) {
            otherTracks[idx].isPlaying.toggle()
            recompute()
        }
    }

    func setSystemVolume(_ v: Int) {
        SystemVolume.set(v)
        for idx in otherTracks.indices { otherTracks[idx].volume = v }
        recompute()
    }

    private var otherTracks: [SpotifyTrack] = []

    private func recompute() {
        var list: [SpotifyTrack] = []
        if !spotifyTrack.isOff { list.append(spotifyTrack) }
        if !musicTrack.isOff { list.append(musicTrack) }
        list.append(contentsOf: otherTracks)
        if available != list { available = list }

        let next = pickActive(from: list)
        let newKey = next.isOff ? "" : "\(next.bundleID)|\(next.name)—\(next.artist)"
        let changed = !next.isOff && !lastKey.isEmpty && newKey != lastKey
        if next != track { track = next }
        if changed { onTrackChange?(next) }
        lastKey = newKey
    }

    private func pickActive(from list: [SpotifyTrack]) -> SpotifyTrack {
        if list.isEmpty { return .off }
        if let pref = settings?.preferredSourceBundleID, !pref.isEmpty,
           let match = list.first(where: { $0.bundleID == pref }) {
            return match
        }
        if let playing = list.first(where: { $0.isPlaying }) { return playing }
        if let sp = list.first(where: { $0.isSpotify }) { return sp }
        if let mu = list.first(where: { $0.isMusic }) { return mu }
        return list[0]
    }

    func setPreferredSource(_ bundleID: String) {
        settings?.preferredSourceBundleID = bundleID
        recompute()
    }

    func tickPosition() {
        guard !track.isOff, track.isPlaying else { return }
        let next = min(track.position + 1, track.duration)
        track.position = next
    }
}

// MARK: - UI state

enum PanelMode { case player, settings, contextMenu, stats, statsData, setup }

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
            PopoverView(state: state, settings: settings, onOpenSetup: { ui.mode = .setup })
        case .settings:
            SettingsView(settings: settings, onOpenStats: { ui.mode = .stats })
        case .contextMenu:
            ContextMenuView(
                lang: settings.language,
                onSettings: { ui.mode = .settings },
                onSetup: { ui.mode = .setup },
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
        case .setup:
            SetupWizardView(
                settings: settings,
                onDone: { ui.mode = .player }
            )
        }
    }
}

// MARK: - Context menu view

struct ContextMenuView: View {
    let lang: String
    let onSettings: () -> Void
    let onSetup: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            MenuRow(icon: "gearshape", label: tr("settings", lang), action: onSettings)
            MenuRow(icon: "globe", label: tr("setup_browsers_menu", lang), action: onSetup)
            Divider().padding(.vertical, 2)
            MenuRow(icon: "power", label: tr("quit", lang), action: onQuit)
        }
        .padding(6)
        .frame(width: 200)
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
    let data: Data?
    let isPlaying: Bool
    let vinyl: Bool
    let size: CGFloat

    @State private var angle: Double = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            artwork
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

    @ViewBuilder
    private var artwork: some View {
        if let data, let img = NSImage(data: data) {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
        } else if let u = URL(string: url), !url.isEmpty {
            AsyncImage(url: u) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(.quaternary)
                }
            }
        } else {
            Rectangle().fill(.quaternary)
        }
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
        .id(runID)
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
    var onOpenSetup: () -> Void = {}
    @State private var accent: Color? = nil
    @State private var bannerDismissed = false
    @State private var anyBrowserUnconfigured = false

    private var showBanner: Bool {
        !settings.onboardingCompleted && !bannerDismissed && anyBrowserUnconfigured
    }

    var body: some View {
        let t = state.track
        VStack(spacing: 0) {
            if showBanner {
                SetupBanner(
                    lang: settings.language,
                    onOpen: {
                        onOpenSetup()
                    },
                    onDismiss: { bannerDismissed = true }
                )
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .frame(width: 360)
            }
            contentBody(t: t)
        }
        .onAppear { refreshBrowserBannerStatus() }
    }

    @ViewBuilder
    private func contentBody(t: SpotifyTrack) -> some View {
        Group {
            if t.isOff {
                VStack(spacing: 14) {
                    Text(tr("nothing_playing", settings.language))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button(tr("open_spotify", settings.language)) {
                            openApp(bundleID: "com.spotify.client")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        Button(tr("open_music", settings.language)) {
                            openApp(bundleID: "com.apple.Music")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                    }
                }
                .frame(width: 360, height: 140)
            } else {
                VStack(spacing: 8) {
                    if state.available.count > 1 {
                        SourceSwitcher(state: state, settings: settings)
                    }
                    HStack(alignment: .top, spacing: 12) {
                        if settings.showImage {
                            Button { openSource(t) } label: {
                                AlbumArtView(
                                    url: t.artUrl,
                                    data: t.artworkData,
                                    isPlaying: t.isPlaying,
                                    vinyl: settings.vinylEnabled,
                                    size: 96
                                )
                            }
                            .buttonStyle(.plain)
                            .help(t.appName)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            if settings.showTitle {
                                Button { openSource(t) } label: {
                                    MarqueeText(text: t.name, font: .system(size: 13, weight: .semibold))
                                }
                                .buttonStyle(.plain)
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
                                    sendPrevious(t)
                                    state.refresh()
                                }
                                ControlButton(system: t.isPlaying ? "pause.fill" : "play.fill") {
                                    sendPlayPause(t)
                                    state.refresh()
                                }
                                ControlButton(system: "forward.fill") {
                                    sendNext(t)
                                    state.refresh()
                                }
                                if t.isSpotify {
                                    ControlButton(system: "shuffle", active: t.shuffling) {
                                        SpotifyAPI.toggleShuffle(!t.shuffling)
                                        state.refresh()
                                    }
                                    ControlButton(system: "repeat", active: t.repeating) {
                                        SpotifyAPI.toggleRepeat(!t.repeating)
                                        state.refresh()
                                    }
                                } else if t.isMusic {
                                    ControlButton(system: "shuffle", active: t.shuffling) {
                                        MusicAPI.toggleShuffle(!t.shuffling)
                                        state.refresh()
                                    }
                                    ControlButton(system: "repeat", active: t.repeating) {
                                        MusicAPI.toggleRepeat(!t.repeating)
                                        state.refresh()
                                    }
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

    private func refreshBrowserBannerStatus() {
        if settings.onboardingCompleted { return }
        DispatchQueue.global(qos: .utility).async {
            let any = BrowserSetup.anyUnconfiguredRunning()
            DispatchQueue.main.async { anyBrowserUnconfigured = any }
        }
    }

    private func sendPrevious(_ t: SpotifyTrack) {
        if t.isSpotify { SpotifyAPI.perform("previous track"); return }
        if t.isMusic { MusicAPI.perform("previous track"); return }
        BrowserJS.previous(bundleID: t.bundleID)
    }

    private func sendPlayPause(_ t: SpotifyTrack) {
        if t.isSpotify { SpotifyAPI.perform("playpause"); return }
        if t.isMusic { MusicAPI.perform("playpause"); return }
        state.optimisticTogglePlaying(for: t)
        BrowserJS.togglePlay(bundleID: t.bundleID)
    }

    private func sendNext(_ t: SpotifyTrack) {
        if t.isSpotify { SpotifyAPI.perform("next track"); return }
        if t.isMusic { MusicAPI.perform("next track"); return }
        BrowserJS.next(bundleID: t.bundleID)
    }

    private func openSource(_ t: SpotifyTrack) {
        if t.isMusic { MusicAPI.reveal() }
        activateAndUnminimize(appName: t.appName, bundleID: t.bundleID)
    }

    private func openApp(bundleID: String) {
        let name = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.localizedName
            ?? (NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.deletingPathExtension().lastPathComponent)
            ?? ""
        activateAndUnminimize(appName: name, bundleID: bundleID)
    }

    private func activateAndUnminimize(appName: String, bundleID: String) {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: cfg, completionHandler: nil)
        }
        guard !appName.isEmpty else { return }
        let src = """
        tell application "\(appName)"
            activate
            try
                repeat with w in windows
                    try
                        set miniaturized of w to false
                    end try
                    try
                        set visible of w to true
                    end try
                end repeat
            end try
            try
                reopen
            end try
        end tell
        """
        var err: NSDictionary?
        NSAppleScript(source: src)?.executeAndReturnError(&err)
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

// MARK: - Setup wizard (browser onboarding)

struct SetupWizardView: View {
    @ObservedObject var settings: AppSettings
    let onDone: () -> Void
    @State private var entries: [(entry: (bundleID: String, appName: String, dialect: BrowserJS.Dialect), status: BrowserSetup.Status)] = []
    @State private var refreshing = false

    private var visible: [(entry: (bundleID: String, appName: String, dialect: BrowserJS.Dialect), status: BrowserSetup.Status)] {
        entries.filter { $0.status != .notInstalled }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("setup_title", settings.language))
                .font(.system(size: 14, weight: .semibold))
            Text(tr("setup_subtitle", settings.language))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if visible.isEmpty {
                Text(tr("setup_status_not_installed", settings.language))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 6) {
                    ForEach(visible, id: \.entry.bundleID) { row in
                        BrowserSetupRow(
                            entry: row.entry,
                            status: row.status,
                            lang: settings.language,
                            onOpen: { BrowserSetup.activate(row.entry) },
                            onRefresh: refresh
                        )
                    }
                }
            }

            HStack {
                Button(tr("setup_recheck", settings.language)) { refresh() }
                    .disabled(refreshing)
                Spacer()
                Button(tr("setup_skip", settings.language)) {
                    settings.onboardingCompleted = true
                    onDone()
                }
                Button(tr("setup_done", settings.language)) {
                    settings.onboardingCompleted = true
                    onDone()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .frame(width: 400)
        .onAppear { refresh() }
    }

    private func refresh() {
        refreshing = true
        DispatchQueue.global(qos: .userInitiated).async {
            let all = BrowserSetup.allStatuses()
            DispatchQueue.main.async {
                entries = all
                refreshing = false
            }
        }
    }
}

struct BrowserSetupRow: View {
    let entry: (bundleID: String, appName: String, dialect: BrowserJS.Dialect)
    let status: BrowserSetup.Status
    let lang: String
    let onOpen: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: status == .configured ? "checkmark.circle.fill" : (status == .notRunning ? "moon.zzz" : "exclamationmark.triangle.fill"))
                .foregroundStyle(statusColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.appName).font(.system(size: 12, weight: .medium))
                Text(instruction).font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text(statusLabel)
                .font(.system(size: 10))
                .foregroundStyle(statusColor)
            if status != .configured {
                Button(tr("setup_open_browser", lang)) { onOpen() }
                    .controlSize(.small)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
    }

    private var instruction: String {
        switch entry.dialect {
        case .chromium: return tr("setup_instruction_chromium", lang)
        case .safari: return tr("setup_instruction_safari", lang)
        }
    }

    private var statusLabel: String {
        switch status {
        case .configured: return tr("setup_status_configured", lang)
        case .unconfigured: return tr("setup_status_unconfigured", lang)
        case .notRunning: return tr("setup_status_not_running", lang)
        case .notInstalled: return tr("setup_status_not_installed", lang)
        }
    }

    private var statusColor: Color {
        switch status {
        case .configured: return .green
        case .unconfigured: return .orange
        case .notRunning: return .secondary
        case .notInstalled: return .secondary
        }
    }
}

struct SetupBanner: View {
    let lang: String
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(tr("setup_banner_title", lang))
                    .font(.system(size: 11, weight: .semibold))
                Text(tr("setup_banner_subtitle", lang))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(tr("setup_open_browser", lang)) { onOpen() }
                .controlSize(.small)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.12)))
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

// MARK: - Source switcher

struct SourceSwitcher: View {
    @ObservedObject var state: SpotifyState
    @ObservedObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 4) {
            ForEach(state.available, id: \.bundleID) { src in
                pill(for: src)
            }
            Spacer(minLength: 0)
        }
    }

    private func pill(for src: SpotifyTrack) -> some View {
        let active = src.bundleID == state.track.bundleID
        let accent = pillTint(for: src)
        return Button(action: {
            state.setPreferredSource(src.bundleID)
        }) {
            HStack(spacing: 4) {
                Image(systemName: pillIcon(for: src))
                    .font(.system(size: 9, weight: .medium))
                Text(src.appName)
                    .font(.system(size: 10, weight: active ? .semibold : .regular))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(active ? accent.opacity(0.22) : Color.primary.opacity(0.08))
            )
            .foregroundStyle(active ? accent : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func pillIcon(for src: SpotifyTrack) -> String {
        if src.isSpotify { return "music.note" }
        if src.isMusic { return "music.note.list" }
        return "dot.radiowaves.left.and.right"
    }

    private func pillTint(for src: SpotifyTrack) -> Color {
        if src.isSpotify { return .green }
        if src.isMusic { return .pink }
        return .blue
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
                    applyVolume()
                },
                onEnded: {
                    applyVolume()
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

    private func applyVolume() {
        let v = Int(localValue)
        if state.track.isSpotify { SpotifyAPI.setVolume(v) }
        else if state.track.isMusic { MusicAPI.setVolume(v) }
        else { state.setSystemVolume(v) }
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
                    if state.track.isSpotify { SpotifyAPI.seek(localValue) }
                    else if state.track.isMusic { MusicAPI.seek(localValue) }
                    else { BrowserJS.seek(bundleID: state.track.bundleID, seconds: localValue) }
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
        DispatchQueue.global(qos: .utility).async {
            BrowserJS.autoEnableJavaScriptFromAppleEvents()
        }
        stats.settings = settings
        state.settings = settings

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

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(spotifyChanged),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(spotifyChanged),
            name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(spotifyChanged),
            name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"),
            object: nil
        )

        modeCancellable = ui.$mode
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.resizePanelForMode() }
            }

        if !settings.onboardingCompleted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.presentSetupOnFirstLaunch()
            }
        }
    }

    private func presentSetupOnFirstLaunch() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let any = BrowserSetup.anyUnconfiguredRunning()
            DispatchQueue.main.async {
                guard let self else { return }
                guard !self.settings.onboardingCompleted else { return }
                if any {
                    self.ui.mode = .setup
                    self.showPanel()
                }
            }
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
