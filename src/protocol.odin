package main

import "core:strings"

// Contract between host (Odin) and page (assets/template.html + app.js).
//
// Hosts:   https://app.local/ = bundled assets, https://doc.local/ = open file's folder.
// Scripts: only app.local serves scripts (CSP). Document scripts never run.
// Page -> host: "ready" | "link:<raw href>"
// Host -> page: "html:<rendered html>" | "status:<text>" (empty text clears status)

APP_HOST     :: "app.local"
DOC_HOST     :: "doc.local"
TEMPLATE_URL :: "https://" + APP_HOST + "/template.html"

Page_Msg :: enum {
	Unknown,
	Ready,
	Link,
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
	return .Unknown, ""
}

html_message :: proc(html: string, allocator := context.allocator) -> string {
	return strings.concatenate({"html:", html}, allocator)
}

status_message :: proc(text: string, allocator := context.allocator) -> string {
	return strings.concatenate({"status:", text}, allocator)
}
