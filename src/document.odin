package main

import "core:fmt"
import "core:os"
import "core:path/filepath"

// load_document reads a Markdown file and renders it. Fails loud: err is a message
// for the status banner. Caller frees html and err.
load_document :: proc(path: string, allocator := context.allocator) -> (html: string, err: string) {
	data, rerr := os.read_entire_file(path, context.temp_allocator)
	if rerr != nil {
		return "", fmt.aprintf("Cannot read %s: %v", path, rerr, allocator = allocator)
	}
	ok: bool
	html, ok = render(string(data), allocator)
	if !ok {
		return "", fmt.aprintf("Cannot render %s: not valid UTF-8", path, allocator = allocator)
	}
	return html, ""
}

// document_dir is the folder served as https://doc.local/.
document_dir :: proc(path: string) -> string {
	dir := filepath.dir(path)
	return dir if dir != "" else "."
}
