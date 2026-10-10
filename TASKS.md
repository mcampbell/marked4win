# TASKS

Run: serial, per `design/SLICES.md`. Done = tests green + `code-reviewer` pass + commit on normal branch.
Odin: `C:\Users\micha\dev\Odin\odin.exe`. CMake: `C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe`.

## Slice 1 - Open and view (branch `slice-1`)
- [x] Confirm C++ workload + CMake in VS 18 (VC 14.51.36231, CMake found)
- [ ] 1a markdown: vendor cmark-gfm, build `.lib`, binding, `render`, tests first
- [ ] 1b webview: confirm `ICoreWebView2_3` host mapping, check Ctrl+F, COM binding, smoke
- [ ] 1c assets: template, CSS light/dark, CSP, highlight.js, link script (agree C2 contract first)
- [ ] 1d shell: window, menu, open dialog, errors, integrate (owns C1)
- [ ] code-reviewer loop (max 5)

## Slice 2 - Watch and reload (branch `slice-2`)
- [ ] watcher: tests first, folder watch, filter, debounce, missing/return
- [ ] shell wiring (C3), scroll-keep (R1)
- [ ] code-reviewer loop

## Slice 3 - Scroll to change and flash (branch `slice-3`)
- [ ] Test `data-sourcepos` on table rows, inline-only edits
- [ ] linediff + tests
- [ ] blockmap + tests
- [ ] scroll + flash script, wiring (replaces R1)
- [ ] code-reviewer loop

## Found
(none yet)
