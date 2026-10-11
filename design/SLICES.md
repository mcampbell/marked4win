# marked4win - Slices

Date: 2026-10-10. Base: `DESIGN.md`. Q&A log: `~/tmp/2026-10-10-marked4win-design-grill.md`.
Costs: see `../estimates.md`.

## Decisions
| Topic | Decision |
|---|---|
| Parser | cmark-gfm, vendored, static `.lib`, Odin `foreign import`. Options: SOURCEPOS + UNSAFE |
| Render | WebView2, hand-written minimal COM binding |
| Hosts | `appassets.example` = bundled assets. `docassets.example` = open file's folder |
| Script guard | CSP: `script-src` only from `appassets.example`. Document scripts never run |
| Raw HTML | Allowed (guarded by CSP) |
| Syntax highlight | highlight.js, bundled, runs in page |
| Theme | Follow Windows light/dark (CSS only) |
| Input | File > Open (slice 1) |
| Links | `http(s)` -> default browser. `#anchor` scrolls. Relative `.md` = no-op |
| Find | WebView2 built-in Ctrl+F (check in slice 1) |
| Selection | Browser default. No saved highlights |
| Errors | Fail loud. Keep last good page. Missing file: "File missing - waiting" |
| Tests | `odin test`, test-first, for pure modules. Manual smoke for GUI |
| Toolchain | `C:\Users\micha\dev\Odin\odin.exe` (use full path). VS 18 Community. Run the dev shell for `cl` |

## Modules (change in isolation)
| Module | File | Does | Depends on |
|---|---|---|---|
| markdown | `src/markdown.odin` | source -> HTML (cmark-gfm) | cmark `.lib` |
| webview | `src/webview.odin` | COM binding: env, controller, navigate, host mapping, resize, JS exec, nav events | Win32 |
| shell | `src/main.odin` + `src/shell.odin` | window, menu, open dialog, message loop, wiring | all |
| assets | `assets/` | template, CSS (light/dark), highlight.js, CSP | none |
| watcher | `src/watcher.odin` | watch folder, filter by name, debounce, missing/return | Win32 |
| linediff | `src/linediff.odin` | LCS line diff -> changed new-line ranges | none |
| blockmap | `src/blockmap.odin` | changed lines -> block ids via `data-sourcepos` | none |

## Slices (deploy order)
### Slice 1 - Open and view (walking skeleton)
Ships: File > Open a `.md`, see it rendered. Tables, code highlight, raw HTML, light/dark, selection, find, links. CSP guard.
Parallel streams (one subagent each):
- 1a markdown: build cmark-gfm `.lib`, binding, `render(src) -> html`. Tests first.
- 1b webview: COM binding. Minimal surface. Manual smoke.
- 1c assets: template, CSS, CSP, highlight.js, anchor + link-click script.
- 1d shell: window, menu, open dialog, errors. Integrates 1a-1c.
First task of 1a: confirm C++ workload / CMake in the VS install.
First task of 1b: confirm `ICoreWebView2_3` host mapping call. Check Ctrl+F.
Merge conflicts: C1, C2 (below).

### Slice 2 - Watch and reload
Ships: file changes on disk -> page re-renders. Keeps scroll offset. Missing file shows status, resumes on return.
Module: watcher (new). Edits shell wiring (C3).
Rework: R1.

### Slice 3 - Scroll to change and flash
Ships: scroll to first changed block. Flash every changed block 2 s.
Modules: linediff, blockmap (new, pure, test first). Small edit to shell + assets.
First task: test `data-sourcepos` on table rows and inline-only edits. Deleted-only lines -> nearest block.
Replaces slice 2 scroll-keep (R1).

## Later (not scheduled)
- Relative `.md` link opens in viewer (watcher switches file).
- CLI path argument.
- Own find bar - only if built-in Ctrl+F fails.
- Out of scope: saved highlights, editing, tabs, cross-platform.

## Deferred edge cases
- Table row / inline-only sourcepos (slice 3 first task).
- Files over huge size: not handled.
- Non-UTF-8 files: not handled in slice 1. Fail loud if invalid UTF-8.

## Merge conflicts and rework (costs in estimates.md)
- C1: Slice 1 streams all touch wiring in `main.odin`. Fix: 1d owns it. Others expose one proc each.
- C2: `template.html` is a contract between 1b (host names) and 1c (CSP, scripts). Fix: agree host names and script list before start.
- C3: Slice 2 edits shell message loop and wiring for watcher events.
- R1: Slice 3 replaces slice 2 scroll-keep logic. Ships slice 2 sooner.
- R2 (conditional): own find bar if built-in find is missing.

## Unconfirmed
- C++ workload and CMake in VS 18 install.
- `ICoreWebView2_3` virtual host mapping API.
- Built-in Ctrl+F in this WebView2 runtime (154.0.4258.62).
- Sourcepos on table rows / inline-only changes.
