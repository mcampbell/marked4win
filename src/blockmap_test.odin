package main

import "core:testing"

@(private = "file")
expect_keys :: proc(t: ^testing.T, got: []string, want: []string, loc := #caller_location) {
	defer delete(got)
	testing.expect_value(t, len(got), len(want), loc = loc)
	if len(got) != len(want) do return
	for k, i in want do testing.expect_value(t, got[i], k, loc = loc)
}

SAMPLE :: `<h1 data-sourcepos="1:1-1:3">H</h1>
<table data-sourcepos="3:1-5:9">
<tr data-sourcepos="3:1-3:9"><th data-sourcepos="3:2-3:4">a</th></tr>
<tr data-sourcepos="5:1-5:9"><td data-sourcepos="5:2-5:4">1</td></tr>
</table>
<p data-sourcepos="8:1-9:11">para
second</p>
<p data-sourcepos="12:1-12:4">end</p>`

@(test)
test_parse_blocks :: proc(t: ^testing.T) {
	blocks := parse_blocks(SAMPLE)
	defer delete(blocks)
	testing.expect_value(t, len(blocks), 7)
	testing.expect_value(t, blocks[0], Block{1, 1, "1:1-1:3"})
	testing.expect_value(t, blocks[5], Block{8, 9, "8:1-9:11"})
}

@(test)
test_parse_blocks_ignores_garbage :: proc(t: ^testing.T) {
	blocks := parse_blocks(`<p data-sourcepos="oops">x</p><p data-sourcepos="2:1-2:3">y</p><p data-sourcepos="`)
	defer delete(blocks)
	testing.expect_value(t, len(blocks), 1)
	testing.expect_value(t, blocks[0].key, "2:1-2:3")
}

@(test)
test_keys_single_block :: proc(t: ^testing.T) {
	blocks := parse_blocks(SAMPLE)
	defer delete(blocks)
	expect_keys(t, changed_keys(blocks, {{9, 9}}), {"8:1-9:11"})
}

@(test)
test_keys_table_row_prefers_row_over_cell :: proc(t: ^testing.T) {
	blocks := parse_blocks(SAMPLE)
	defer delete(blocks)
	expect_keys(t, changed_keys(blocks, {{5, 5}}), {"5:1-5:9"})
}

@(test)
test_keys_inside_table_picks_smaller_than_table :: proc(t: ^testing.T) {
	blocks := parse_blocks(SAMPLE)
	defer delete(blocks)
	expect_keys(t, changed_keys(blocks, {{3, 3}}), {"3:1-3:9"})
}

@(test)
test_keys_blank_line_goes_to_nearest_block :: proc(t: ^testing.T) {
	blocks := parse_blocks(SAMPLE)
	defer delete(blocks)
	expect_keys(t, changed_keys(blocks, {{7, 7}}), {"8:1-9:11"}) // 1 line from p(8), 2 from table(5)
	expect_keys(t, changed_keys(blocks, {{20, 20}}), {"12:1-12:4"}) // past the end
}

@(test)
test_keys_deduped_and_in_document_order :: proc(t: ^testing.T) {
	blocks := parse_blocks(SAMPLE)
	defer delete(blocks)
	expect_keys(t, changed_keys(blocks, {{12, 12}, {8, 9}, {1, 1}}), {"1:1-1:3", "8:1-9:11", "12:1-12:4"})
}

@(test)
test_keys_nothing :: proc(t: ^testing.T) {
	blocks := parse_blocks(SAMPLE)
	defer delete(blocks)
	expect_keys(t, changed_keys(blocks, {}), {})
	expect_keys(t, changed_keys({}, {{1, 1}}), {})
}

// End to end with real cmark output: edit -> ranges -> keys.
@(private = "file")
keys_for_edit :: proc(old_md, new_md: string) -> []string {
	html, ok := render(new_md)
	defer delete(html)
	if !ok do return nil
	blocks := parse_blocks(html, context.temp_allocator)
	ranges := changed_ranges(old_md, new_md)
	defer delete(ranges)
	return changed_keys(blocks, ranges)
}

@(test)
test_e2e_table_cell_edit_flashes_row :: proc(t: ^testing.T) {
	expect_keys(t, keys_for_edit("# H\n\n| a | b |\n|---|---|\n| 1 | 2 |\n", "# H\n\n| a | b |\n|---|---|\n| 1 | 9 |\n"), {"5:1-5:9"})
}

@(test)
test_e2e_inline_edit_flashes_paragraph :: proc(t: ^testing.T) {
	expect_keys(t, keys_for_edit("para with **bold** text\n", "para with **BOLD** text\n"), {"1:1-1:24"})
}

@(test)
test_e2e_deleted_only_flashes_neighbour :: proc(t: ^testing.T) {
	expect_keys(t, keys_for_edit("# A\n\npara\n\nlast\n", "# A\n\nlast\n"), {"3:1-3:4"})
}
