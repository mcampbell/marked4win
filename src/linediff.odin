package main

import "base:runtime"
import "core:strings"

// Line diff (LCS). Answers: which lines of the NEW text changed?
// Pure deletions have no new line, so they point at the nearest one (the line that
// followed the deleted text, or the last line).

Line_Range :: struct {
	first, last: int, // 1-based, inclusive, in the new text
}

// Common prefix and suffix are trimmed first. If the rest needs more than max_cells
// LCS cells, the whole rest counts as changed (bounded memory, still correct to the eye).
DEFAULT_MAX_CELLS :: 4_000_000

changed_ranges :: proc(
	old_src, new_src: string,
	max_cells := DEFAULT_MAX_CELLS,
	allocator := context.allocator,
) -> []Line_Range {
	a := split_lines(old_src, context.temp_allocator)
	b := split_lines(new_src, context.temp_allocator)
	if len(b) == 0 do return nil

	pre := 0
	for pre < len(a) && pre < len(b) && a[pre] == b[pre] do pre += 1
	suf := 0
	for suf < len(a) - pre && suf < len(b) - pre && a[len(a) - 1 - suf] == b[len(b) - 1 - suf] do suf += 1
	am, bm := a[pre:len(a) - suf], b[pre:len(b) - suf]

	changed := make([]bool, len(b), context.temp_allocator)
	if len(am) * len(bm) > max_cells {
		for j in 0 ..< len(bm) do changed[pre + j] = true
	} else {
		mark_lcs_changes(am, bm, pre, changed)
	}
	return to_ranges(changed, allocator)
}

// mark_lcs_changes walks the LCS table. Hunk = run of non-matching lines between matches.
@(private = "file")
mark_lcs_changes :: proc(am, bm: []string, offset: int, changed: []bool) {
	m, n := len(am), len(bm)
	w := n + 1
	dp := make([]i32, (m + 1) * w, context.temp_allocator) // dp[i*w+j] = LCS(am[i:], bm[j:])
	for i := m - 1; i >= 0; i -= 1 {
		for j := n - 1; j >= 0; j -= 1 {
			dp[i * w + j] = dp[(i + 1) * w + j + 1] + 1 if am[i] == bm[j] else max(dp[(i + 1) * w + j], dp[i * w + j + 1])
		}
	}

	i, j := 0, 0
	hunk_inserted, hunk_deleted := false, false
	deleted_at := 0
	flush :: proc(changed: []bool, inserted, deleted: bool, at: int) {
		if deleted && !inserted do changed[min(at, len(changed) - 1)] = true
	}

	for i < m || j < n {
		if i < m && j < n && am[i] == bm[j] {
			flush(changed, hunk_inserted, hunk_deleted, deleted_at)
			hunk_inserted, hunk_deleted = false, false
			i += 1
			j += 1
		} else if i < m && (j == n || dp[(i + 1) * w + j] >= dp[i * w + j + 1]) {
			if !hunk_deleted do deleted_at = offset + j
			hunk_deleted = true
			i += 1
		} else {
			hunk_inserted = true
			changed[offset + j] = true
			j += 1
		}
	}
	flush(changed, hunk_inserted, hunk_deleted, deleted_at)
}

@(private = "file")
to_ranges :: proc(changed: []bool, allocator: runtime.Allocator) -> []Line_Range {
	out := make([dynamic]Line_Range, allocator)
	for c, idx in changed {
		if !c do continue
		line := idx + 1
		if n := len(out); n > 0 && out[n - 1].last == line - 1 {
			out[n - 1].last = line
		} else {
			append(&out, Line_Range{line, line})
		}
	}
	return out[:]
}

// split_lines splits on \n, drops \r and one trailing newline (so CRLF == LF).
@(private = "file")
split_lines :: proc(s: string, allocator: runtime.Allocator) -> []string {
	out := make([dynamic]string, allocator)
	rest := s
	for len(rest) > 0 {
		line := rest
		if i := strings.index_byte(rest, '\n'); i >= 0 {
			line, rest = rest[:i], rest[i + 1:]
		} else {
			rest = ""
		}
		append(&out, strings.trim_suffix(line, "\r"))
	}
	return out[:]
}
