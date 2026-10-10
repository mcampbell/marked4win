# Estimates

Scale: trivial/easy/medium/hard = 0.5/1/2/4 points. Relative within this session only. Points, not time.

## Work
| Slice | Item | Points |
|---|---|---|
| 1 | 1a markdown: build cmark-gfm lib, binding, render, tests | 2 |
| 1 | 1b webview: COM binding (env, controller, navigate, host map, JS, events) | 4 |
| 1 | 1c assets: template, CSS light/dark, CSP, highlight.js, link script | 1 |
| 1 | 1d shell: window, menu, open dialog, errors, integration | 2 |
| 2 | watcher: folder watch, name filter, debounce, missing/resume, wiring | 2 |
| 3 | linediff (LCS) + tests | 1 |
| 3 | blockmap + tests | 1 |
| 3 | scroll + flash script, wiring | 1 |

## Merge conflicts and rework
| ID | Item | Points |
|---|---|---|
| C1 | `main.odin` wiring shared by slice 1 streams | 0.5 |
| C2 | `template.html` contract between 1b and 1c | 0.5 |
| C3 | Slice 2 edits shell loop and wiring | 0.5 |
| R1 | Slice 3 replaces slice 2 scroll-keep | 0.5 |
| R2 | Own find bar, only if built-in Ctrl+F fails (conditional) | 2 |

## Totals
- Work: 14. Conflicts + rework (certain): 2. Conditional: 2.
