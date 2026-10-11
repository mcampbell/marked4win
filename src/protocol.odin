package main

import "core:strings"

// Contract between host (Odin) and page (assets/template.html + app.js).
//
// Hosts:   https://appassets.example/ = bundled assets, https://docassets.example/ = open file's folder.
// Scripts: only appassets.example serves scripts (CSP). Document scripts never run.
// Page -> host: "ready" | "link:<raw href>" | "font:<name>"
// Host -> page also: "font:<name>" (sent on every "ready", a reload resets the page)
// Host -> page: "html:<html>" (keep scroll) | "newdoc:<html>" (scroll to top)
//               | "changed:<key>|<key>..." (scroll to first block, flash all; key = data-sourcepos value)
//               | "status:<text>" (empty text clears status)

// Never use a ".local" host: Chromium resolves it with mDNS and waits ~2 s on every navigation.
// ".example" is reserved (RFC 2606) and skips the lookup.
APP_HOST     :: "appassets.example"
DOC_HOST     :: "docassets.example"
TEMPLATE_URL :: "https://" + APP_HOST + "/template.html"

Page_Msg :: enum {
	Unknown,
	Ready,
	Link,
	Font, // page changed the font with Ctrl+1/2/3; host syncs the menu
}

Font :: enum {
	Sans, // default
	Serif,
	Mono,
}

@(private = "file")
FONT_NAMES := [Font]string{.Sans = "sans", .Serif = "serif", .Mono = "mono"}

font_from_name :: proc(name: string) -> (f: Font, ok: bool) {
	for n, font in FONT_NAMES {
		if n == name do return font, true
	}
	return .Sans, false
}

// font_message is the same shape both ways: "font:<sans|serif|mono>".
font_message :: proc(f: Font, allocator := context.allocator) -> string {
	return strings.concatenate({"font:", FONT_NAMES[f]}, allocator)
}

// nav_allowed: top-level navigation may only reach the template page (plus #fragment).
nav_allowed :: proc(uri: string) -> bool {
	if uri == TEMPLATE_URL do return true
	return strings.has_prefix(uri, TEMPLATE_URL + "#")
}

// link_is_external: only http(s) links leave the viewer (default browser).
link_is_external :: proc(href: string) -> bool {
	return has_prefix_fold(href, "http://") || has_prefix_fold(href, "https://")
}

@(private = "file")
has_prefix_fold :: proc(s, prefix: string) -> bool {
	return len(s) >= len(prefix) && strings.equal_fold(s[:len(prefix)], prefix)
}

parse_page_message :: proc(msg: string) -> (kind: Page_Msg, arg: string) {
	if msg == "ready" do return .Ready, ""
	if strings.has_prefix(msg, "link:") do return .Link, msg[len("link:"):]
	if strings.has_prefix(msg, "font:") do return .Font, msg[len("font:"):]
	return .Unknown, ""
}

// new_doc: a different file was opened (page scrolls to top). Otherwise the page keeps its scroll offset.
html_message :: proc(html: string, new_doc := false, allocator := context.allocator) -> string {
	return strings.concatenate({"newdoc:" if new_doc else "html:", html}, allocator)
}

// changed_message lists the data-sourcepos keys of changed blocks (document order).
// The page scrolls to the first and flashes all of them for 2 s.
changed_message :: proc(keys: []string, allocator := context.allocator) -> string {
	joined := strings.join(keys, "|", context.temp_allocator)
	return strings.concatenate({"changed:", joined}, allocator)
}

status_message :: proc(text: string, allocator := context.allocator) -> string {
	return strings.concatenate({"status:", text}, allocator)
}
