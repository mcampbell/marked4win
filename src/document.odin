package main

import "core:fmt"
import "core:os"
import "core:path/filepath"

// load_document reads a Markdown file and renders it. Fails loud: err is a message
// for the status banner. Returns the source too (for the line diff). Caller frees src, html, err.
load_document :: proc(path: string, allocator := context.allocator) -> (src, html, err: string) {
	data, rerr := os.read_entire_file(path, allocator)
	if rerr != nil {
		return "", "", fmt.aprintf("Cannot read %s: %v", path, rerr, allocator = allocator)
	}
	src = string(data)
	ok: bool
	html, ok = render(src, allocator)
	if !ok {
		delete(src, allocator)
		return "", "", fmt.aprintf("Cannot render %s: not valid UTF-8", path, allocator = allocator)
	}
	return src, html, ""
}

// document_dir is the folder served as https://doc.local/.
document_dir :: proc(path: string) -> string {
	dir := filepath.dir(path)
	return dir if dir != "" else "."
}
