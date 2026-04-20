# NowBar

Native macOS menu bar app for Spotify. Built with Swift + SwiftUI + AppKit.

## Features

- Track info in menu bar (song - artist)
- Popover with album art, title, artist, album
- Playback controls: prev, play/pause, next
- Shuffle toggle
- Vertical volume slider
- Instant updates via `com.spotify.client.PlaybackStateChanged`
- Multi-source: también detecta y controla audio reproduciéndose en navegadores (YouTube, YouTube Music, SoundCloud, Spotify Web, Twitch, Netflix, Vimeo, Bandcamp, Deezer, Tidal, Apple Music web, etc)
- Apple Music (Music.app) soportado como fuente primaria (igual que Spotify): controles completos, shuffle/repeat, artwork via iTunes Search API
- Click en portada o título abre la app fuente con la canción seleccionada (Music.app usa `reveal`)

## Navegadores soportados

NowBar usa AppleScript para inyectar JavaScript en la pestaña activa del navegador. Para que funcione, **cada navegador necesita habilitar "Allow JavaScript from Apple Events" una sola vez**.

NowBar intenta habilitar esto automáticamente al arrancar (via `defaults write`), pero macOS moderno suele ignorar esos cambios por seguridad. Si los controles del navegador no responden, habilítalo manualmente:

### Chromium (Chrome, Brave, Edge, Arc, Opera, Vivaldi)

1. Abre el navegador
2. Menú **Ver → Desarrollador → Permitir JavaScript de eventos de Apple** (en EN: `View → Developer → Allow JavaScript from Apple Events`)
3. Reinicia el navegador

Si no ves el submenú "Desarrollador":
- **Chrome/Brave/Edge**: aparece por defecto
- **Arc**: Ajustes → Avanzado → activar "Developer menu"

### Safari

1. Safari → **Ajustes → Avanzado → marcar "Mostrar menú Desarrollar en la barra de menús"**
2. Menú **Desarrollar → Permitir JavaScript de Apple Events**
3. También marcar **Desarrollar → Permitir ejecución remota**
4. Reinicia Safari

### Firefox

**No soportado.** Firefox no expone una API de AppleScript que permita ejecutar JavaScript en pestañas. Si necesitas controlar audio en Firefox, usa las teclas multimedia del teclado o los controles nativos del sitio.

### Permiso de Automatización

La primera vez que NowBar intente controlar un navegador, macOS mostrará un diálogo pidiendo permiso ("NowBar wants to control …"). Acepta. Si lo rechazaste por error, habilítalo manualmente en **Ajustes del Sistema → Privacidad y Seguridad → Automatización → NowBar**.

### Sitios detectados

NowBar solo inspecciona pestañas cuya URL contenga dominios de media conocidos:

```
youtube.com, music.youtube.com, soundcloud.com, spotify.com,
twitch.tv, vimeo.com, netflix.com, bandcamp.com,
mixcloud.com, deezer.com, tidal.com, apple.com/music
```

Esto evita escanear decenas de pestañas y mejora performance. Si necesitas un sitio adicional, edítalo en `BrowserJS.mediaHostsClause` en `Sources/NowBar/main.swift`.

## Requisitos

- macOS 14 (Sonoma) o superior
- Xcode Command Line Tools (para el compilador Swift): `xcode-select --install`
- Al menos una de estas apps: Spotify, Music.app, o un navegador soportado

## Instalación desde cero

Pasos para alguien que acaba de clonar el repositorio.

### 1. Clonar y compilar

```bash
git clone <url-del-repo> NowBar
cd NowBar
swift build -c release
```

El binario queda en `.build/release/NowBar`.

### 2. Empaquetar como `.app` e instalar

```bash
APP=/Applications/NowBar.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/NowBar "$APP/Contents/MacOS/NowBar"
cp Info.plist "$APP/Contents/Info.plist"
cp nowbar-icon.icns "$APP/Contents/Resources/nowbar-icon.icns"
codesign --force --deep --sign - "$APP"
open "$APP"
```

Deberías ver el icono ♪ en la barra de menú.

### 3. Primera ejecución — permisos

macOS te pedirá varios permisos la primera vez que NowBar intente controlar otras apps. **Acepta todos** (son solo para leer estado de reproducción y enviar comandos play/pause/next).

- "NowBar quiere controlar Spotify" → **OK**
- "NowBar quiere controlar Music" → **OK**
- "NowBar quiere controlar Brave/Chrome/Safari/…" → **OK** (si usas navegador)

Si lo rechazaste por error, actívalo manualmente en:
**Ajustes del Sistema → Privacidad y Seguridad → Automatización → NowBar**

### 4. Habilitar JavaScript en navegadores (solo si usas control de pestañas)

Ver sección [Navegadores soportados](#navegadores-soportados) arriba. Obligatorio para Chromium y Safari, una sola vez por navegador. Para Spotify y Music.app no hace falta nada.

### 5. (Opcional) Arranque automático al iniciar sesión

```bash
cp com.canai.nowbar.plist ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/com.canai.nowbar.plist
```

Para desactivarlo:
```bash
launchctl unload ~/Library/LaunchAgents/com.canai.nowbar.plist
rm ~/Library/LaunchAgents/com.canai.nowbar.plist
```

## Actualizar

```bash
git pull
swift build -c release
pkill -f "NowBar.app/Contents/MacOS/NowBar"
cp .build/release/NowBar /Applications/NowBar.app/Contents/MacOS/NowBar
codesign --force --deep --sign - /Applications/NowBar.app
open /Applications/NowBar.app
```

## Desinstalar

```bash
pkill -f NowBar
launchctl unload ~/Library/LaunchAgents/com.canai.nowbar.plist 2>/dev/null
rm -rf /Applications/NowBar.app ~/Library/LaunchAgents/com.canai.nowbar.plist
```

## Troubleshooting

- **El icono no aparece**: reabre con `open /Applications/NowBar.app`. Verifica permisos de Automatización.
- **Controles del navegador no responden**: falta habilitar "Allow JavaScript from Apple Events" en ese navegador (ver sección arriba) y reiniciarlo.
- **Spotify/Music no aparece**: asegúrate de que la app esté reproduciendo (no en estado `stopped`).
- **Ventana minimizada no se reabre al hacer click**: si ocurre, repórtalo con versión de macOS.

## Stack

- Swift + SwiftUI + AppKit (`NSStatusItem`, `NSPopover`)
- AppleScript bridge via `NSAppleScript`
- `DistributedNotificationCenter` for Spotify events
- `launchd` LaunchAgent for auto-start
