package main

import "base:runtime"
import "core:fmt"
import win "core:sys/windows"

// Minimal hand-written WebView2 COM binding. Vtable layouts come from WebView2.h
// (Microsoft.Web.WebView2 1.0.4258.31). `_: [N]rawptr` skips methods we do not call.

foreign import wv2loader "../vendor/webview2/WebView2Loader.dll.lib"

@(default_calling_convention = "system")
foreign wv2loader {
	CreateCoreWebView2EnvironmentWithOptions :: proc(browser_dir, user_data_dir: win.LPCWSTR, options, handler: rawptr) -> win.HRESULT ---
}

E_NOINTERFACE :: win.HRESULT(-2147467262) // 0x80004002

IID_IUnknown :: win.GUID{0x00000000, 0x0000, 0x0000, {0xC0, 0, 0, 0, 0, 0, 0, 0x46}}
IID_View3    :: win.GUID{0xA0D6DF20, 0x3B92, 0x416D, {0xAA, 0x0C, 0x43, 0x7A, 0x9C, 0x72, 0x78, 0x57}}
IID_Env_Completed  :: win.GUID{0x4e8a3389, 0xc9d8, 0x4bd2, {0xb6, 0xb5, 0x12, 0x4f, 0xee, 0x6c, 0xc1, 0x4d}}
IID_Ctrl_Completed :: win.GUID{0x6c4819f3, 0xc9b7, 0x4260, {0x81, 0x27, 0xc9, 0xf5, 0xbd, 0xe7, 0xf6, 0x8c}}
IID_Nav_Starting   :: win.GUID{0x9adbe429, 0xf36d, 0x432b, {0x9d, 0xdc, 0xf8, 0x88, 0x1f, 0xbd, 0x76, 0xe3}}
IID_Web_Message    :: win.GUID{0x57213f19, 0x00e6, 0x49fa, {0x8e, 0x07, 0x89, 0x8e, 0xa0, 0x1e, 0xcb, 0xd2}}

Unknown :: win.IUnknown
Base_VT :: win.IUnknown_VTable

// ICoreWebView2Environment
Environment :: struct { vtbl: ^Environment_VT }
Environment_VT :: struct {
	using base: Base_VT,
	CreateCoreWebView2Controller: proc "system" (this: ^Environment, parent: win.HWND, handler: rawptr) -> win.HRESULT, // 3
}

// ICoreWebView2Controller
Controller :: struct { vtbl: ^Controller_VT }
Controller_VT :: struct {
	using base: Base_VT,
	_:               [1]rawptr, // 3 get_IsVisible
	put_IsVisible:   proc "system" (this: ^Controller, visible: win.BOOL) -> win.HRESULT, // 4
	_:               [1]rawptr, // 5 get_Bounds
	put_Bounds:      proc "system" (this: ^Controller, bounds: win.RECT) -> win.HRESULT, // 6
	_:               [5]rawptr, // 7..11
	MoveFocus:       proc "system" (this: ^Controller, reason: i32) -> win.HRESULT, // 12
	_:               [10]rawptr, // 13..22
	_:               [1]rawptr, // 23 NotifyParentWindowPositionChanged
	Close:           proc "system" (this: ^Controller) -> win.HRESULT, // 24
	get_CoreWebView2: proc "system" (this: ^Controller, out: ^^View) -> win.HRESULT, // 25
}

// ICoreWebView2
View :: struct { vtbl: ^View_VT }
View_VT :: struct {
	using base: Base_VT,
	_:                       [2]rawptr, // 3 get_Settings, 4 get_Source
	Navigate:                proc "system" (this: ^View, uri: win.LPCWSTR) -> win.HRESULT, // 5
	_:                       [1]rawptr, // 6 NavigateToString
	add_NavigationStarting:  proc "system" (this: ^View, handler: rawptr, token: ^i64) -> win.HRESULT, // 7
	_:                       [25]rawptr, // 8..32
	PostWebMessageAsString:  proc "system" (this: ^View, msg: win.LPCWSTR) -> win.HRESULT, // 33
	add_WebMessageReceived:  proc "system" (this: ^View, handler: rawptr, token: ^i64) -> win.HRESULT, // 34
}

// ICoreWebView2_3 (inherits ICoreWebView2 3..60, ICoreWebView2_2 61..67)
View3 :: struct { vtbl: ^View3_VT }
View3_VT :: struct {
	using base: Base_VT,
	_: [68]rawptr, // 3..70
	SetVirtualHostNameToFolderMapping: proc "system" (this: ^View3, host, folder: win.LPCWSTR, access: i32) -> win.HRESULT, // 71
}
HOST_ACCESS_ALLOW     :: 1 // doc.local: page on app.local loads its images (cross-origin)
HOST_ACCESS_DENY_CORS :: 2

NavStart_Args :: struct { vtbl: ^NavStart_Args_VT }
NavStart_Args_VT :: struct {
	using base: Base_VT,
	get_Uri:    proc "system" (this: ^NavStart_Args, uri: ^win.LPWSTR) -> win.HRESULT, // 3
	_:          [4]rawptr, // 4..7
	put_Cancel: proc "system" (this: ^NavStart_Args, cancel: win.BOOL) -> win.HRESULT, // 8
}

WebMsg_Args :: struct { vtbl: ^WebMsg_Args_VT }
WebMsg_Args_VT :: struct {
	using base: Base_VT,
	_: [2]rawptr, // 3 get_Source, 4 get_WebMessageAsJson
	TryGetWebMessageAsString: proc "system" (this: ^WebMsg_Args, msg: ^win.LPWSTR) -> win.HRESULT, // 5
}

// Handler objects: static lifetime inside Webview, so reference counts never free.
Handler :: struct {
	vtbl: rawptr, // must stay first
	iid:  win.GUID,
	wv:   ^Webview,
	refs: u32,
}

Webview :: struct {
	hwnd:       win.HWND,
	app_dir:    string,
	on_message: proc(wv: ^Webview, msg: string),
	on_error:   proc(wv: ^Webview, msg: string),

	env:        ^Environment,
	controller: ^Controller,
	view:       ^View,
	view3:      ^View3,
	bounds:     win.RECT,
	tokens:     [2]i64,

	h_env, h_ctrl, h_nav, h_msg: Handler,
}

@(private = "file")
Env_Completed_VT :: struct {
	using base: Base_VT,
	Invoke:     proc "system" (this: ^Handler, hr: win.HRESULT, env: ^Environment) -> win.HRESULT,
}
@(private = "file")
Ctrl_Completed_VT :: struct {
	using base: Base_VT,
	Invoke:     proc "system" (this: ^Handler, hr: win.HRESULT, ctrl: ^Controller) -> win.HRESULT,
}
@(private = "file")
Nav_Starting_VT :: struct {
	using base: Base_VT,
	Invoke:     proc "system" (this: ^Handler, sender: ^View, args: ^NavStart_Args) -> win.HRESULT,
}
@(private = "file")
Web_Message_VT :: struct {
	using base: Base_VT,
	Invoke:     proc "system" (this: ^Handler, sender: ^View, args: ^WebMsg_Args) -> win.HRESULT,
}

@(private = "file")
env_vt := Env_Completed_VT{{h_query, h_addref, h_release}, on_env_completed}
@(private = "file")
ctrl_vt := Ctrl_Completed_VT{{h_query, h_addref, h_release}, on_ctrl_completed}
@(private = "file")
nav_vt := Nav_Starting_VT{{h_query, h_addref, h_release}, on_nav_starting}
@(private = "file")
msg_vt := Web_Message_VT{{h_query, h_addref, h_release}, on_web_message}

@(private = "file")
h_query :: proc "system" (this: ^Unknown, riid: win.REFIID, out: ^rawptr) -> win.HRESULT {
	h := (^Handler)(this)
	if riid^ == IID_IUnknown || riid^ == h.iid {
		out^ = this
		h.refs += 1
		return win.S_OK
	}
	out^ = nil
	return E_NOINTERFACE
}
@(private = "file")
h_addref :: proc "system" (this: ^Unknown) -> win.ULONG {
	h := (^Handler)(this)
	h.refs += 1
	return h.refs
}
@(private = "file")
h_release :: proc "system" (this: ^Unknown) -> win.ULONG {
	h := (^Handler)(this)
	h.refs -= 1
	return h.refs
}

// webview_init starts async creation. Needs COM initialized (STA) on this thread.
// Pass `wv` with hwnd, app_dir, on_message, on_error set. wv must outlive the window.
webview_init :: proc(wv: ^Webview, user_data_dir: string) -> bool {
	wv.h_env  = {&env_vt, IID_Env_Completed, wv, 1}
	wv.h_ctrl = {&ctrl_vt, IID_Ctrl_Completed, wv, 1}
	wv.h_nav  = {&nav_vt, IID_Nav_Starting, wv, 1}
	wv.h_msg  = {&msg_vt, IID_Web_Message, wv, 1}

	hr := CreateCoreWebView2EnvironmentWithOptions(
		nil,
		win.utf8_to_wstring(user_data_dir, context.temp_allocator),
		nil,
		&wv.h_env,
	)
	if win.FAILED(hr) {
		fail(wv, "create environment", hr)
		return false
	}
	return true
}

webview_resize :: proc(wv: ^Webview, width, height: i32) {
	wv.bounds = {0, 0, width, height}
	if wv.controller != nil do wv.controller.vtbl.put_Bounds(wv.controller, wv.bounds)
}

// webview_post sends a string to the page. Ignored until the view exists.
webview_post :: proc(wv: ^Webview, msg: string) {
	if wv.view == nil do return
	wv.view.vtbl.PostWebMessageAsString(wv.view, win.utf8_to_wstring(msg, context.temp_allocator))
}

// webview_map_doc_folder serves `folder` at https://doc.local/.
webview_map_doc_folder :: proc(wv: ^Webview, folder: string) -> bool {
	return map_host(wv, DOC_HOST, folder, HOST_ACCESS_ALLOW)
}

// webview_reload navigates to the template again. Host mappings only apply to new
// navigations, so reload after webview_map_doc_folder. The page sends "ready" again.
webview_reload :: proc(wv: ^Webview) {
	if wv.view == nil do return
	wv.view.vtbl.Navigate(wv.view, win.utf8_to_wstring(TEMPLATE_URL, context.temp_allocator))
}

// webview_focus gives keyboard focus to the page (needed for built-in Ctrl+F).
webview_focus :: proc(wv: ^Webview) {
	if wv.controller != nil do wv.controller.vtbl.MoveFocus(wv.controller, 0) // PROGRAMMATIC
}

webview_close :: proc(wv: ^Webview) {
	if wv.controller != nil do wv.controller.vtbl.Close(wv.controller)
}

@(private = "file")
map_host :: proc(wv: ^Webview, host, folder: string, access: i32) -> bool {
	if wv.view3 == nil do return false
	hr := wv.view3.vtbl.SetVirtualHostNameToFolderMapping(
		wv.view3,
		win.utf8_to_wstring(host, context.temp_allocator),
		win.utf8_to_wstring(folder, context.temp_allocator),
		access,
	)
	if win.FAILED(hr) {
		fail(wv, fmt.tprintf("map %s", host), hr)
		return false
	}
	return true
}

@(private = "file")
fail :: proc(wv: ^Webview, what: string, hr: win.HRESULT) {
	if wv.on_error != nil do wv.on_error(wv, fmt.tprintf("WebView2: %s failed (0x%08x)", what, u32(hr)))
}

@(private = "file")
on_env_completed :: proc "system" (this: ^Handler, hr: win.HRESULT, env: ^Environment) -> win.HRESULT {
	context = runtime.default_context()
	wv := this.wv
	if win.FAILED(hr) || env == nil {
		fail(wv, "environment", hr)
		return win.S_OK
	}
	env.vtbl.AddRef((^Unknown)(env))
	wv.env = env
	hr2 := env.vtbl.CreateCoreWebView2Controller(env, wv.hwnd, &wv.h_ctrl)
	if win.FAILED(hr2) do fail(wv, "create controller", hr2)
	return win.S_OK
}

@(private = "file")
on_ctrl_completed :: proc "system" (this: ^Handler, hr: win.HRESULT, ctrl: ^Controller) -> win.HRESULT {
	context = runtime.default_context()
	wv := this.wv
	if win.FAILED(hr) || ctrl == nil {
		fail(wv, "controller", hr)
		return win.S_OK
	}
	ctrl.vtbl.AddRef((^Unknown)(ctrl))
	wv.controller = ctrl

	if h := ctrl.vtbl.get_CoreWebView2(ctrl, &wv.view); win.FAILED(h) {
		fail(wv, "get view", h)
		return win.S_OK
	}
	iid := IID_View3
	if h := wv.view.vtbl.QueryInterface((^Unknown)(wv.view), &iid, (^rawptr)(&wv.view3)); win.FAILED(h) {
		fail(wv, "ICoreWebView2_3 (host mapping)", h)
		return win.S_OK
	}
	if !map_host(wv, APP_HOST, wv.app_dir, HOST_ACCESS_DENY_CORS) do return win.S_OK

	wv.view.vtbl.add_NavigationStarting(wv.view, &wv.h_nav, &wv.tokens[0])
	wv.view.vtbl.add_WebMessageReceived(wv.view, &wv.h_msg, &wv.tokens[1])
	ctrl.vtbl.put_Bounds(ctrl, wv.bounds)
	ctrl.vtbl.put_IsVisible(ctrl, true)
	wv.view.vtbl.Navigate(wv.view, win.utf8_to_wstring(TEMPLATE_URL, context.temp_allocator))
	webview_focus(wv)
	return win.S_OK
}

@(private = "file")
on_nav_starting :: proc "system" (this: ^Handler, sender: ^View, args: ^NavStart_Args) -> win.HRESULT {
	context = runtime.default_context()
	uri_w: win.LPWSTR
	if win.FAILED(args.vtbl.get_Uri(args, &uri_w)) do return win.S_OK
	defer win.CoTaskMemFree(uri_w)
	uri, _ := win.wstring_to_utf8(win.wstring(uri_w), -1, context.temp_allocator)
	if !nav_allowed(uri) do args.vtbl.put_Cancel(args, true)
	return win.S_OK
}

@(private = "file")
on_web_message :: proc "system" (this: ^Handler, sender: ^View, args: ^WebMsg_Args) -> win.HRESULT {
	context = runtime.default_context()
	msg_w: win.LPWSTR
	if win.FAILED(args.vtbl.TryGetWebMessageAsString(args, &msg_w)) do return win.S_OK
	defer win.CoTaskMemFree(msg_w)
	msg, _ := win.wstring_to_utf8(win.wstring(msg_w), -1, context.temp_allocator)
	if this.wv.on_message != nil do this.wv.on_message(this.wv, msg)
	return win.S_OK
}
