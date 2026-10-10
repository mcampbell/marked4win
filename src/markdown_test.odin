package main

import "core:strings"
import "core:testing"

@(test)
test_render_heading :: proc(t: ^testing.T) {
	html, ok := render("# Hi")
	defer delete(html)
	testing.expect(t, ok)
	testing.expect(t, strings.contains(html, "<h1"), html)
	testing.expect(t, strings.contains(html, "Hi</h1>"), html)
}

@(test)
test_render_table :: proc(t: ^testing.T) {
	html, ok := render("| a | b |\n|---|---|\n| 1 | 2 |\n")
	defer delete(html)
	testing.expect(t, ok)
	testing.expect(t, strings.contains(html, "<table"), html)
	testing.expect(t, strings.contains(html, "<td"), html)
}

@(test)
test_render_strikethrough_and_tasklist :: proc(t: ^testing.T) {
	html, ok := render("~~gone~~\n\n- [x] done\n")
	defer delete(html)
	testing.expect(t, ok)
	testing.expect(t, strings.contains(html, "<del>gone</del>"), html)
	testing.expect(t, strings.contains(html, "checkbox"), html)
}

@(test)
test_render_sourcepos :: proc(t: ^testing.T) {
	html, ok := render("# A\n\npara\n")
	defer delete(html)
	testing.expect(t, ok)
	testing.expect(t, strings.contains(html, `data-sourcepos="3:1-3:4"`), html)
}

@(test)
test_render_keeps_raw_html :: proc(t: ^testing.T) {
	html, ok := render("<div class=\"x\">raw</div>\n")
	defer delete(html)
	testing.expect(t, ok)
	testing.expect(t, strings.contains(html, `<div class="x">raw</div>`), html)
}

@(test)
test_render_code_block_language_class :: proc(t: ^testing.T) {
	html, ok := render("```odin\nx := 1\n```\n")
	defer delete(html)
	testing.expect(t, ok)
	testing.expect(t, strings.contains(html, `class="language-odin"`), html)
}

@(test)
test_render_empty :: proc(t: ^testing.T) {
	html, ok := render("")
	defer delete(html)
	testing.expect(t, ok)
	testing.expect_value(t, html, "")
}

@(test)
test_render_rejects_invalid_utf8 :: proc(t: ^testing.T) {
	html, ok := render("a\xffb")
	defer delete(html)
	testing.expect(t, !ok)
}
