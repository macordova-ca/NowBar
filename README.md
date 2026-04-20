# NowBar

App nativa para la barra de menú de macOS. Construida con Swift + SwiftUI + AppKit.

## Descarga

La forma más simple de instalar NowBar es descargar el `.dmg` desde la página de releases:

1. Ve a **[Releases](https://github.com/macordova-ca/NowBar/releases/latest)** y descarga `NowBar-<versión>.dmg`
2. Abre el `.dmg` y arrastra **NowBar.app** a la carpeta **Applications**
3. Abre NowBar desde Launchpad o Finder. La primera vez macOS puede bloquear la app porque la firma es ad-hoc:
   - Click derecho sobre **NowBar.app** → **Abrir** → confirma en el diálogo
4. El icono ♪ aparece en la barra de menú. El wizard interno te guía para habilitar los navegadores que uses.

Si prefieres compilar desde código, ve a [Instalación desde cero](#instalación-desde-cero).

## Características

- Información de la pista en la barra de menú (canción - artista)
- Popover con portada, título, artista y álbum
- Controles de reproducción: anterior, play/pausa, siguiente
- Toggle de shuffle y repeat
- Slider vertical de volumen
- Actualizaciones instantáneas vía `com.spotify.client.PlaybackStateChanged`
- Multi-fuente: también detecta y controla audio que se reproduce en navegadores (YouTube, YouTube Music, SoundCloud, Spotify Web, Twitch, Netflix, Vimeo, Bandcamp, Deezer, Tidal, Apple Music web, etc.)
- Apple Music (Music.app) soportado como fuente primaria (igual que Spotify): controles completos, shuffle/repeat, artwork vía iTunes Search API
- Hacer click en la portada o en el título abre la app fuente con la canción seleccionada (Music.app usa `reveal`)

## Navegadores soportados

NowBar usa AppleScript para inyectar JavaScript en la pestaña activa del navegador. Para que funcione, **cada navegador necesita habilitar "Allow JavaScript from Apple Events" una sola vez**.

NowBar intenta habilitar esto automáticamente al iniciar (vía `defaults write`), pero las versiones modernas de macOS suelen ignorar esos cambios por seguridad. Si los controles del navegador no responden, habilítalo manualmente:

### Chromium (Chrome, Brave, Edge, Arc, Opera, Vivaldi)

1. Abre el navegador
2. Menú **Ver → Desarrollador → Permitir JavaScript de eventos de Apple** (en inglés: `View → Developer → Allow JavaScript from Apple Events`)
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

### Permiso de automatización

La primera vez que NowBar intente controlar un navegador, macOS mostrará un diálogo pidiendo permiso ("NowBar wants to control …"). Acepta. Si lo rechazaste por error, habilítalo manualmente en **Ajustes del Sistema → Privacidad y Seguridad → Automatización → NowBar**.

### Sitios detectados

NowBar solo inspecciona pestañas cuya URL contenga dominios de media conocidos:

```
youtube.com, music.youtube.com, soundcloud.com, spotify.com,
twitch.tv, vimeo.com, netflix.com, bandcamp.com,
mixcloud.com, deezer.com, tidal.com, apple.com/music
```

Esto evita escanear decenas de pestañas y mejora el rendimiento. Si necesitas un sitio adicional, edítalo en `BrowserJS.mediaHostsClause` dentro de `Sources/NowBar/main.swift`.

## Requisitos

- macOS 14 (Sonoma) o superior
- Xcode Command Line Tools (para el compilador de Swift): `xcode-select --install`
- Al menos una de estas apps: Spotify, Music.app o un navegador soportado

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

macOS pedirá varios permisos la primera vez que NowBar intente controlar otras apps. **Acepta todos** (solo sirven para leer el estado de reproducción y enviar comandos play/pausa/siguiente).

- "NowBar quiere controlar Spotify" → **OK**
- "NowBar quiere controlar Music" → **OK**
- "NowBar quiere controlar Brave/Chrome/Safari/…" → **OK** (si usas navegador)

Si lo rechazaste por error, actívalo manualmente en:
**Ajustes del Sistema → Privacidad y Seguridad → Automatización → NowBar**

### 4. Habilitar JavaScript en navegadores (solo si usas control de pestañas)

Ver la sección [Navegadores soportados](#navegadores-soportados) arriba. Es obligatorio para Chromium y Safari, una sola vez por navegador. Para Spotify y Music.app no hace falta nada.

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

## Solución de problemas

- **El icono no aparece**: reabre con `open /Applications/NowBar.app`. Verifica los permisos de Automatización.
- **Los controles del navegador no responden**: falta habilitar "Allow JavaScript from Apple Events" en ese navegador (ver sección arriba) y reiniciarlo.
- **Spotify/Music no aparece**: asegúrate de que la app esté reproduciendo (no en estado `stopped`).
- **La ventana minimizada no se reabre al hacer click**: si ocurre, repórtalo indicando la versión de macOS.

## Stack

- Swift + SwiftUI + AppKit (`NSStatusItem`, `NSPopover`)
- Puente con AppleScript vía `NSAppleScript`
- `DistributedNotificationCenter` para eventos de Spotify
- LaunchAgent de `launchd` para arranque automático
