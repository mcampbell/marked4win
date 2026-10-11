package main

import "core:strings"

// Contract between host (Odin) and page (assets/template.html + app.js).
//
// Hosts:   https://app.local/ = bundled assets, https://doc.local/ = open file's folder.
// Scripts: only app.local serves scripts (CSP). Document scripts never run.
// Page -> host: "ready" | "link:<raw href>"
// Host -> page: "html:<html>" (keep scroll) | "newdoc:<html>" (scroll to top)
//               | "changed:<key>|<key>..." (scroll to first block, flash all; key = data-sourcepos value)
//               | "status:<text>" (empty text clears status)

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
