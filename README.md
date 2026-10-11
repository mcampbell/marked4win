# marked4win

Native Windows Markdown viewer. Written in Odin. Renders with WebView2.

- Open a `.md` file. See tables, code highlight, raw HTML, light/dark theme.
- The viewer watches the open file. On a change it re-renders, scrolls to the first changed block, and flashes the changed blocks for 2 s.
- Built-in find: Ctrl+F.
- Fonts: View menu or Ctrl+1 sans-serif (default), Ctrl+2 serif, Ctrl+3 monospace. Code blocks stay monospace. The choice resets when you restart the app.

## Build

### Requirements

- Windows 10 or 11, x64.
- [Odin](https://odin-lang.org) compiler. The build script expects `C:\Users\micha\dev\Odin\odin.exe`. Edit `$odin` in `build.ps1` for another path.
- Visual Studio (Community is enough) with the C++ workload. Odin uses its linker.
- PowerShell.

The libraries are in the repo, so you do not need CMake for a normal build:

| Path | What |
|---|---|
| `vendor/cmark-gfm/lib/` | cmark-gfm static libs (`/MT`) |
| `vendor/webview2/` | `WebView2Loader.dll` and import lib |
| `assets/` | page template, CSS, highlight.js, page script |

### Steps

```powershell
odin test src          # run tests first (50 tests)
.\build.ps1            # build into build\
```

Output in `build\`:

```
build\marked4win.exe
build\WebView2Loader.dll
build\assets\            (template.html, app.js, styles.css, highlight.min.js, ...)
```

### Rebuild cmark-gfm (rare)

Do this only to update the parser. Use a VS developer shell.

```powershell
git clone --depth 1 https://github.com/github/cmark-gfm.git <src-dir>
.\vendor\build-cmark.ps1 <src-dir> <build-dir>
```

The libs must use `/MT`. Odin links the static C runtime. A `/MD` lib fails to link.

## Run

```powershell
.\build\marked4win.exe                 # then File > Open
.\build\marked4win.exe path\to\file.md # open a file at start
```

## Deploy to another Windows machine

1. Build on the dev machine (see above).
2. Copy the whole `build\` folder to the target. Keep the three items together:
   `marked4win.exe`, `WebView2Loader.dll`, and the `assets\` folder.
   The exe finds `assets\` next to itself.
3. Make sure the target has the **WebView2 Runtime**.
   - Windows 11: already installed.
   - Windows 10: install the Evergreen runtime from
     <https://developer.microsoft.com/microsoft-edge/webview2/>.
4. Run `marked4win.exe`. No installer. No admin rights.

The target needs no Odin, no Visual Studio, and no C++ runtime install.

### Install to Program Files

The app writes only to `%LOCALAPPDATA%\marked4win`, so a read-only install folder works.
Run this in an **administrator** PowerShell, from the repo folder:

```powershell
$dest = "$env:ProgramFiles\marked4win"
New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item .\build\* $dest -Recurse -Force
```

Add a Start menu shortcut (all users):

```powershell
$lnk = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\marked4win.lnk")
$lnk.TargetPath = "$dest\marked4win.exe"
$lnk.WorkingDirectory = $dest
$lnk.Save()
```

No admin rights? Use a per-user folder. Same commands, with `$dest = "$env:LOCALAPPDATA\Programs\marked4win"` and the shortcut in `$env:APPDATA\Microsoft\Windows\Start Menu\Programs`.

To update, close the app and copy `build\*` again. To remove, delete the install folder, the shortcut, and `%LOCALAPPDATA%\marked4win`.

The `.md` file association is manual: right-click a `.md` file, then Open with > Choose another app > `marked4win.exe`.

WebView2 stores its data in `%LOCALAPPDATA%\marked4win`. Delete the folder to reset.

### Quick check on the target

- The window opens with a `File` menu and no error box.
- File > Open shows a `.md` file.
- Edit the file in another editor and save. The page updates.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Error box "WebView2: create environment failed" | WebView2 Runtime missing. Install it. |
| Blank white window | `assets\` is missing next to the exe. Copy it. |
| App does not start, "WebView2Loader.dll not found" | Copy `WebView2Loader.dll` next to the exe. |
| Link error `__imp_...` at build | A cmark lib was built with `/MD`. Rebuild with `/MT`. |
| Local images do not show | The image is outside the open file's folder. Only that folder is served. |

## Layout

```
src/        Odin source (package main)
  markdown      cmark-gfm binding, render()
  webview       WebView2 COM binding
  protocol      page <-> host messages, navigation and link rules
  document      read file, render, folder
  watcher       file poll state machine
  linediff      LCS line diff
  blockmap      changed lines -> blocks
  shell, main   window, menu, wiring
assets/     page files served to WebView2 as https://appassets.example/
vendor/     cmark-gfm and WebView2 loader
design/     DESIGN.md, SLICES.md
```

## Security notes

- The page allows scripts only from `appassets.example` (CSP). Scripts inside a document never run.
- Raw HTML in a document renders. Remote `https:` images load.
- Only `http(s)` links open, in the default browser.

## License notes

Third-party code: cmark-gfm (`vendor/cmark-gfm/COPYING`), WebView2 loader (`vendor/webview2/LICENSE.txt`), highlight.js (`assets/LICENSE-highlightjs.txt`).
