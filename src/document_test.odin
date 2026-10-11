package main

import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

@(private = "file")
write_temp :: proc(name: string, data: []byte) -> string {
	dir, _ := os.temp_directory(context.temp_allocator)
	path, _ := filepath.join({dir, name}, context.temp_allocator)
	_ = os.write_entire_file(path, data)
	return path
}

@(test)
test_load_document_ok :: proc(t: ^testing.T) {
	path := write_temp("m4w_ok.md", transmute([]byte)string("# Title\n"))
	defer os.remove(path)

	html, err := load_document(path)
	defer delete(html)
	testing.expect_value(t, err, "")
	testing.expect(t, strings.contains(html, "<h1"), html)
}

@(test)
test_load_document_missing :: proc(t: ^testing.T) {
	html, err := load_document("Z:\\no\\such\\file.md")
	defer delete(html)
	defer delete(err)
	testing.expect_value(t, html, "")
	testing.expect(t, strings.contains(err, "Cannot read"), err)
}

@(test)
test_load_document_invalid_utf8 :: proc(t: ^testing.T) {
	path := write_temp("m4w_bad.md", []byte{'a', 0xff, 'b'})
	defer os.remove(path)

	html, err := load_document(path)
	defer delete(html)
	defer delete(err)
	testing.expect_value(t, html, "")
	testing.expect(t, strings.contains(err, "UTF-8"), err)
}

@(test)
test_document_dir :: proc(t: ^testing.T) {
	testing.expect_value(t, document_dir("C:\\docs\\notes\\a.md"), "C:\\docs\\notes")
	testing.expect_value(t, document_dir("a.md"), ".")
}
