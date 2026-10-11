package main

import "core:testing"

@(test)
test_nav_allowed_template :: proc(t: ^testing.T) {
	testing.expect(t, nav_allowed("https://appassets.example/template.html"))
	testing.expect(t, nav_allowed("https://appassets.example/template.html#intro"))
}

@(test)
test_nav_blocks_everything_else :: proc(t: ^testing.T) {
	testing.expect(t, !nav_allowed("https://example.com/"))
	testing.expect(t, !nav_allowed("https://docassets.example/other.md"))
	testing.expect(t, !nav_allowed("https://appassets.example/other.html"))
	testing.expect(t, !nav_allowed("https://appassets.example.evil.com/template.html"))
	testing.expect(t, !nav_allowed("https://appassets.example@evil.com/template.html"))
	testing.expect(t, !nav_allowed("https://evil.com/https://appassets.example/template.html"))
	testing.expect(t, !nav_allowed("http://appassets.example/template.html"))
	testing.expect(t, !nav_allowed("file:///c:/x.html"))
	testing.expect(t, !nav_allowed(""))
}

@(test)
test_link_is_external :: proc(t: ^testing.T) {
	testing.expect(t, link_is_external("http://example.com"))
	testing.expect(t, link_is_external("https://example.com/a?b=1"))
	testing.expect(t, link_is_external("HTTPS://Example.com"))
	testing.expect(t, !link_is_external("other.md"))
	testing.expect(t, !link_is_external("#anchor"))
	testing.expect(t, !link_is_external("mailto:a@b.c"))
	testing.expect(t, !link_is_external("javascript:alert(1)"))
	testing.expect(t, !link_is_external("file:///c:/x"))
	testing.expect(t, !link_is_external(""))
}

@(test)
test_parse_page_message :: proc(t: ^testing.T) {
	kind, arg := parse_page_message("ready")
	testing.expect_value(t, kind, Page_Msg.Ready)
	testing.expect_value(t, arg, "")

	kind, arg = parse_page_message("link:https://example.com/a:b")
	testing.expect_value(t, kind, Page_Msg.Link)
	testing.expect_value(t, arg, "https://example.com/a:b")

	kind, _ = parse_page_message("bogus")
	testing.expect_value(t, kind, Page_Msg.Unknown)
	kind, _ = parse_page_message("")
	testing.expect_value(t, kind, Page_Msg.Unknown)
}

@(test)
test_host_messages :: proc(t: ^testing.T) {
	h := html_message("<p>x</p>")
	defer delete(h)
	testing.expect_value(t, h, "html:<p>x</p>")

	n := html_message("<p>x</p>", new_doc = true)
	defer delete(n)
	testing.expect_value(t, n, "newdoc:<p>x</p>")

	s := status_message("File missing - waiting")
	defer delete(s)
	testing.expect_value(t, s, "status:File missing - waiting")

	k := changed_message({"1:1-1:3", "8:1-9:11"})
	defer delete(k)
	testing.expect_value(t, k, "changed:1:1-1:3|8:1-9:11")

	c := status_message("")
	defer delete(c)
	testing.expect_value(t, c, "status:")
}
