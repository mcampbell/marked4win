package main

import "core:testing"

@(private = "file")
expect_ranges :: proc(t: ^testing.T, got: []Line_Range, want: []Line_Range, loc := #caller_location) {
	defer delete(got)
	testing.expect_value(t, len(got), len(want), loc = loc)
	if len(got) != len(want) do return
	for r, i in want do testing.expect_value(t, got[i], r, loc = loc)
}

@(test)
test_diff_identical :: proc(t: ^testing.T) {
	expect_ranges(t, changed_ranges("a\nb\nc\n", "a\nb\nc\n"), {})
}

@(test)
test_diff_changed_middle_line :: proc(t: ^testing.T) {
	expect_ranges(t, changed_ranges("a\nb\nc\n", "a\nX\nc\n"), {{2, 2}})
}

@(test)
test_diff_appended_line :: proc(t: ^testing.T) {
	expect_ranges(t, changed_ranges("a\nb\n", "a\nb\nc\n"), {{3, 3}})
}

@(test)
test_diff_adjacent_inserts_merge :: proc(t: ^testing.T) {
	expect_ranges(t, changed_ranges("a\nd\n", "a\nb\nc\nd\n"), {{2, 3}})
}

@(test)
test_diff_two_separate_edits :: proc(t: ^testing.T) {
	expect_ranges(t, changed_ranges("a\nb\nc\nd\ne\n", "a\nX\nc\nd\nY\n"), {{2, 2}, {5, 5}})
}

@(test)
test_diff_deleted_only_points_at_next_line :: proc(t: ^testing.T) {
	// old line 2 removed: new line 2 ("c") is the nearest line
	expect_ranges(t, changed_ranges("a\nb\nc\n", "a\nc\n"), {{2, 2}})
}

@(test)
test_diff_deleted_last_line_clamps :: proc(t: ^testing.T) {
	expect_ranges(t, changed_ranges("a\nb\nc\n", "a\nb\n"), {{2, 2}})
}

@(test)
test_diff_to_empty_is_no_target :: proc(t: ^testing.T) {
	expect_ranges(t, changed_ranges("a\nb\n", ""), {})
}

@(test)
test_diff_from_empty_marks_everything :: proc(t: ^testing.T) {
	expect_ranges(t, changed_ranges("", "a\nb\n"), {{1, 2}})
}

@(test)
test_diff_ignores_line_ending_style :: proc(t: ^testing.T) {
	expect_ranges(t, changed_ranges("a\r\nb\r\n", "a\nb"), {})
}

@(test)
test_diff_reordered_blocks :: proc(t: ^testing.T) {
	// "b" leaves its old place (nearest new line 2) and appears at line 3
	expect_ranges(t, changed_ranges("a\nb\nc\n", "a\nc\nb\n"), {{2, 3}})
}

@(test)
test_diff_over_budget_marks_whole_middle :: proc(t: ^testing.T) {
	// prefix "a" and suffix "z" stay; the middle is too big for the LCS table
	expect_ranges(t, changed_ranges("a\nb\nc\nz\n", "a\nX\nY\nz\n", max_cells = 1), {{2, 3}})
}
