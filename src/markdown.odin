package main

import "core:strings"
import "core:sync"
import "core:unicode/utf8"

foreign import cmark {
	"../vendor/cmark-gfm/lib/cmark-gfm-extensions_static.lib",
	"../vendor/cmark-gfm/lib/cmark-gfm_static.lib",
}

Cmark_Parser    :: distinct rawptr
Cmark_Node      :: distinct rawptr
Cmark_Extension :: distinct rawptr
Cmark_List      :: distinct rawptr

Cmark_Mem :: struct {
	calloc:  proc "c" (n, size: uint) -> rawptr,
	realloc: proc "c" (p: rawptr, size: uint) -> rawptr,
	free:    proc "c" (p: rawptr),
}

CMARK_OPT_SOURCEPOS :: 1 << 1
CMARK_OPT_UNSAFE    :: 1 << 17

@(default_calling_convention = "c", link_prefix = "cmark_")
foreign cmark {
	gfm_core_extensions_ensure_registered :: proc() ---
	find_syntax_extension                 :: proc(name: cstring) -> Cmark_Extension ---
	parser_new                            :: proc(options: i32) -> Cmark_Parser ---
	parser_free                           :: proc(p: Cmark_Parser) ---
	parser_attach_syntax_extension        :: proc(p: Cmark_Parser, e: Cmark_Extension) -> i32 ---
	parser_get_syntax_extensions          :: proc(p: Cmark_Parser) -> Cmark_List ---
	parser_feed                           :: proc(p: Cmark_Parser, buf: [^]u8, n: uint) ---
	parser_finish                         :: proc(p: Cmark_Parser) -> Cmark_Node ---
	node_free                             :: proc(n: Cmark_Node) ---
	render_html                           :: proc(n: Cmark_Node, options: i32, ext: Cmark_List) -> cstring ---
	get_default_mem_allocator             :: proc() -> ^Cmark_Mem ---
}

@(private = "file")
EXTENSIONS :: [?]cstring{"table", "strikethrough", "autolink", "tasklist"}

// cmark's extension registry is not thread-safe: register once.
@(private = "file")
registered: sync.Once

@(private = "file")
register_extensions :: proc() {
	gfm_core_extensions_ensure_registered()
}

// render converts Markdown to HTML. Raw HTML passes through (CSP guards the page).
// Every block carries data-sourcepos. Returns ok=false on invalid UTF-8. Caller frees html.
render :: proc(src: string, allocator := context.allocator) -> (html: string, ok: bool) {
	if !utf8.valid_string(src) do return "", false

	sync.once_do(&registered, register_extensions)
	parser :=parser_new(CMARK_OPT_SOURCEPOS | CMARK_OPT_UNSAFE)
	defer parser_free(parser)
	for name in EXTENSIONS {
		if ext := find_syntax_extension(name); ext != nil {
			parser_attach_syntax_extension(parser, ext)
		}
	}

	parser_feed(parser, raw_data(src), uint(len(src)))
	root := parser_finish(parser)
	defer node_free(root)

	out := render_html(root, CMARK_OPT_SOURCEPOS | CMARK_OPT_UNSAFE, parser_get_syntax_extensions(parser))
	if out == nil do return "", false
	defer get_default_mem_allocator().free(rawptr(out))

	return strings.clone_from_cstring(out, allocator), true
}
