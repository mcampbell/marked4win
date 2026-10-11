package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import win "core:sys/windows"

ID_FILE_OPEN :: 1001
ID_FILE_EXIT :: 1002
ID_VIEW_SANS :: 1101 // + Font ordinal: sans, serif, mono
ID_VIEW_MONO :: ID_VIEW_SANS + 2
#assert(ID_VIEW_MONO - ID_VIEW_SANS == int(max(Font)))

foreign import user32 "system:User32.lib"

@(default_calling_convention = "system")
foreign user32 {
	CheckMenuRadioItem :: proc(menu: win.HMENU, first, last, check, flags: win.UINT) -> win.BOOL ---
}

APP_NAME :: "marked4win"

// One window per process: the shell state is a package-level singleton.
Shell :: struct {
	hwnd:  win.HWND,
	wv:    Webview,
	ready: bool,   // page sent "ready"; safe to post content
	path:  string, // open document ("" = none)

	mapped_dir: string, // folder currently served as docassets.example
	src:        string, // text the page shows, for the line diff
	watch:      Watch,
	font:       Font,
	view_menu:  win.HMENU,
	new_doc:    bool, // next post is a different file: page scrolls to top
}

TIMER_WATCH :: 1
MSG_MISSING :: "File missing - waiting"

@(private = "file")
shell: Shell

shell_run :: proc() -> bool {
	instance := win.HINSTANCE(win.GetModuleHandleW(nil))
	class := win.WNDCLASSEXW {
		cbSize        = size_of(win.WNDCLASSEXW),
		lpfnWndProc   = wnd_proc,
		hInstance     = instance,
		hCursor       = win.LoadCursorW(nil, transmute(win.LPCWSTR)win.IDC_ARROW),
		hbrBackground = win.HBRUSH(uintptr(win.COLOR_WINDOW + 1)),
		lpszClassName = win.L(APP_NAME),
	}
	if win.RegisterClassExW(&class) == 0 {
		fatal("Cannot register window class")
		return false
	}

	hwnd := win.CreateWindowExW(
		0, class.lpszClassName, win.L(APP_NAME), win.WS_OVERLAPPEDWINDOW,
		win.CW_USEDEFAULT, win.CW_USEDEFAULT, 1100, 800,
		nil, make_menu(), instance, nil,
	)
	if hwnd == nil {
		fatal("Cannot create window")
		return false
	}
	shell.hwnd = hwnd
	set_font(.Sans, post = false)

	shell.wv = Webview {
		hwnd       = hwnd,
		app_dir    = fmt.aprintf("%s\\assets", exe_dir()),
		on_message = on_page_message,
		on_error   = on_webview_error,
	}
	if len(os.args) > 1 { // opened once the page is ready
		// host mapping needs an absolute folder
		path, _ := filepath.abs(os.args[1])
		show_file(path, new_doc = true)
	}
	if !webview_init(&shell.wv, user_data_dir()) do return false

	win.ShowWindow(hwnd, win.SW_SHOWDEFAULT)
	win.UpdateWindow(hwnd)
	sync_size()
	win.SetTimer(hwnd, TIMER_WATCH, POLL_MS, nil)

	msg: win.MSG
	for win.GetMessageW(&msg, nil, 0, 0) > 0 {
		win.TranslateMessage(&msg)
		win.DispatchMessageW(&msg)
		free_all(context.temp_allocator)
	}
	return true
}

@(private = "file")
make_menu :: proc() -> win.HMENU {
	file := win.CreatePopupMenu()
	win.AppendMenuW(file, win.MF_STRING, ID_FILE_OPEN, win.L("&Open..."))
	win.AppendMenuW(file, win.MF_STRING, ID_FILE_EXIT, win.L("E&xit"))
	// Ctrl+1/2/3 are handled by the page (it owns keyboard focus); the labels only show them.
	shell.view_menu = win.CreatePopupMenu()
	labels := [Font]win.LPCWSTR{.Sans = win.L("Sans-serif\tCtrl+1"), .Serif = win.L("Serif\tCtrl+2"), .Mono = win.L("Monospace\tCtrl+3")}
	for f in Font {
		win.AppendMenuW(shell.view_menu, win.MF_STRING, win.UINT_PTR(ID_VIEW_SANS + int(f)), labels[f])
	}
	bar := win.CreateMenu()
	win.AppendMenuW(bar, win.MF_POPUP, win.UINT_PTR(uintptr(file)), win.L("&File"))
	win.AppendMenuW(bar, win.MF_POPUP, win.UINT_PTR(uintptr(shell.view_menu)), win.L("&View"))
	return bar
}

@(private = "file")
wnd_proc :: proc "system" (hwnd: win.HWND, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) -> win.LRESULT {
	context = runtime.default_context()
	switch msg {
	case win.WM_COMMAND:
		switch win.LOWORD(win.DWORD(wparam)) {
		case ID_FILE_OPEN:
			if path, ok := open_dialog(hwnd); ok do show_file(path, new_doc = true)
		case ID_FILE_EXIT:
			win.DestroyWindow(hwnd)
		case ID_VIEW_SANS ..= ID_VIEW_MONO:
			set_font(Font(int(win.LOWORD(win.DWORD(wparam))) - ID_VIEW_SANS), post = true)
		}
		return 0
	case win.WM_TIMER:
		if wparam == TIMER_WATCH do poll_watch()
		return 0
	case win.WM_SIZE:
		sync_size()
		return 0
	case win.WM_SETFOCUS, win.WM_EXITMENULOOP:
		// Without this, Ctrl+1/2/3 and Ctrl+F stop working after a menu closes.
		webview_focus(&shell.wv)
		return 0
	case win.WM_DESTROY:
		webview_close(&shell.wv)
		win.PostQuitMessage(0)
		return 0
	}
	return win.DefWindowProcW(hwnd, msg, wparam, lparam)
}

@(private = "file")
sync_size :: proc() {
	rect: win.RECT
	win.GetClientRect(shell.hwnd, &rect)
	webview_resize(&shell.wv, rect.right - rect.left, rect.bottom - rect.top)
}

// set_font records the choice and moves the radio mark. post: tell the page (menu
// clicks do; a page-side Ctrl+1/2/3 already changed the page).
@(private = "file")
set_font :: proc(f: Font, post: bool) {
	shell.font = f
	id := win.UINT(ID_VIEW_SANS + int(f))
	CheckMenuRadioItem(shell.view_menu, ID_VIEW_SANS, ID_VIEW_MONO, id, win.MF_BYCOMMAND)
	if post do webview_post(&shell.wv, font_message(f, context.temp_allocator))
}

@(private = "file")
poll_watch :: proc() {
	if shell.path == "" || !shell.ready do return
	switch watch_step(&shell.watch, file_sig(shell.path)) {
	case .Reload:
		show_file(shell.path)
	case .Missing:
		webview_post(&shell.wv, status_message(MSG_MISSING, context.temp_allocator))
	case .None:
	}
}

// show_file renders `path` into the page. On failure keep the last good page
// and put the error in the status banner. new_doc: user opened this file (reset
// scroll, restart the watcher). Re-renders of the same file keep the scroll offset.
@(private = "file")
show_file :: proc(path: string, new_doc := false) {
	if new_doc {
		shell.new_doc = true
		shell.watch = watch_start(file_sig(path))
	}
	shell.path = path
	if !shell.ready do return // on_page_message("ready") calls us again

	src, html, err := load_document(path, context.temp_allocator)
	if err != "" {
		webview_post(&shell.wv, status_message(err, context.temp_allocator))
		return
	}
	// A new folder needs a new navigation to take effect: map, reload, and wait for "ready".
	if dir := document_dir(path); dir != shell.mapped_dir {
		if !webview_map_doc_folder(&shell.wv, dir) do return
		delete(shell.mapped_dir)
		shell.mapped_dir = strings.clone(dir)
		shell.ready = false
		webview_reload(&shell.wv)
		return
	}
	webview_post(&shell.wv, html_message(html, shell.new_doc, context.temp_allocator))
	if !shell.new_doc do flash_changes(src, html)
	shell.new_doc = false
	delete(shell.src)
	shell.src = strings.clone(src)
	webview_post(&shell.wv, status_message("", context.temp_allocator))
	win.SetWindowTextW(shell.hwnd, win.utf8_to_wstring(fmt.tprintf("%s - %s", filepath.base(path), APP_NAME)))
}

// flash_changes tells the page which blocks differ from the text it showed before.
@(private = "file")
flash_changes :: proc(src, html: string) {
	ranges := changed_ranges(shell.src, src, allocator = context.temp_allocator)
	keys := changed_keys(parse_blocks(html, context.temp_allocator), ranges, context.temp_allocator)
	if len(keys) > 0 do webview_post(&shell.wv, changed_message(keys, context.temp_allocator))
}

@(private = "file")
on_page_message :: proc(wv: ^Webview, msg: string) {
	kind, arg := parse_page_message(msg)
	switch kind {
	case .Font:
		if f, ok := font_from_name(arg); ok do set_font(f, post = false)
	case .Ready:
		shell.ready = true
		webview_post(&shell.wv, font_message(shell.font, context.temp_allocator)) // a reload resets the page
		if shell.path != "" do show_file(shell.path)
	case .Link:
		if link_is_external(arg) {
			win.ShellExecuteW(nil, win.L("open"), win.utf8_to_wstring(arg), nil, nil, win.SW_SHOWNORMAL)
		}
	case .Unknown:
	}
}

@(private = "file")
on_webview_error :: proc(wv: ^Webview, msg: string) {
	fatal(msg)
}

@(private = "file")
fatal :: proc(text: string) {
	win.MessageBoxW(shell.hwnd, win.utf8_to_wstring(text), win.L(APP_NAME), win.MB_OK | win.MB_ICONERROR)
}

@(private = "file")
open_dialog :: proc(owner: win.HWND) -> (path: string, ok: bool) {
	filter := win.utf8_to_utf16("Markdown\x00*.md;*.markdown;*.mdown\x00All files\x00*.*\x00\x00", context.temp_allocator)
	buf: [1024]u16
	ofn := win.OPENFILENAMEW {
		lStructSize = size_of(win.OPENFILENAMEW),
		hwndOwner   = owner,
		lpstrFilter = win.LPCWSTR(raw_data(filter)),
		lpstrFile   = win.LPWSTR(&buf[0]),
		nMaxFile    = len(buf),
		Flags       = win.OPEN_FLAGS,
	}
	if !win.GetOpenFileNameW(&ofn) do return "", false
	p, _ := win.wstring_to_utf8(win.wstring(&buf[0]), -1, context.allocator)
	return p, true
}

@(private = "file")
exe_dir :: proc() -> string {
	buf: [win.MAX_PATH]u16
	n := win.GetModuleFileNameW(nil, win.LPWSTR(&buf[0]), len(buf))
	exe, _ := win.wstring_to_utf8(win.wstring(&buf[0]), int(n), context.temp_allocator)
	return filepath.dir(exe)
}

@(private = "file")
user_data_dir :: proc() -> string {
	base := os.get_env("LOCALAPPDATA", context.temp_allocator)
	return fmt.tprintf("%s\\%s", base if base != "" else ".", APP_NAME)
}
