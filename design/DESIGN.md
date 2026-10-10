# marked4win Design

## Project Goal
Native Windows Markdown viewer in Odin. Personal use. Minimal GUI with standard Windows controls. No animation, no cross-platform.

## Features
- View Markdown files
- Support for all common Markdown features:
  - Headers, bold, italic, lists, blockquotes, links
  - **Code blocks with syntax highlighting**
  - **Tables**
- Scrolling
- Custom highlighting (text selection)

## Architecture

### Technology Stack
- **Language:** Odin
- **Rendering:** WebView2 (Edge rendering)
- **Markdown Parser:** C library (like `cmark`) or JavaScript (`marked.js`)
- **Syntax Highlighting:** highlight.js (bundled)
- **UI:** Win32 API native controls

### Why WebView2?
- All Markdown features work automatically (tables, complex formatting)
- Syntax highlighting is trivial (highlight.js)
- Minimal code—tables and code highlighting "just work"
- Scrolling handled by the browser
- Much simpler than custom rendering

### Basic Flow
1. User opens Markdown file (File → Open)
2. Parse Markdown → HTML
3. Render in WebView2 control
4. User scrolls, selects, finds text

### Rendering Options
- **Option A:** Parse Markdown in Odin using C library (`cmark`), output HTML, display in WebView2
- **Option B:** Inject Markdown into WebView2, use JavaScript library (`marked.js`) to parse client-side

Option B is simpler (no C dependency). Option A is slightly more performant.

## Project Structure
```
marked4win/
├── src/
│   ├── main.odin
│   ├── webview.odin
│   ├── markdown.odin
│   └── file_handler.odin
├── assets/
│   ├── template.html
│   ├── styles.css
│   └── highlight.min.js
└── design/
    └── DESIGN.md
```

## No External Dependencies?
User confirmed: **fine with external libs and deps**. So WebView2 + C Markdown library or JavaScript libs are all on the table.
