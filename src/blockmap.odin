package main

import "core:strconv"
import "core:strings"

// Maps changed lines to rendered blocks. cmark-gfm tags every block with
// data-sourcepos="line:col-line:col". The key we send to the page is that attribute
// value itself: the page finds the element with querySelectorAll, no ordinals to drift.

Block :: struct {
	first, last: int,    // source lines, inclusive
	key:         string, // the data-sourcepos value (slice of the html)
}

@(private = "file")
SOURCEPOS_ATTR :: `data-sourcepos="`

// parse_blocks lists every element with data-sourcepos, in document order.
parse_blocks :: proc(html: string, allocator := context.allocator) -> []Block {
	out := make([dynamic]Block, allocator)
	rest := html
	for {
		i := strings.index(rest, SOURCEPOS_ATTR)
		if i < 0 do break
		rest = rest[i + len(SOURCEPOS_ATTR):]
		end := strings.index_byte(rest, '"')
		if end < 0 do break
		key := rest[:end]
		rest = rest[end + 1:]
		if first, last, ok := parse_sourcepos(key); ok {
			append(&out, Block{first, last, key})
		}
	}
	return out[:]
}

// changed_keys returns the block keys to flash, deduped, in document order.
// Per changed line: the smallest block that covers it (outer block wins a tie, so a
// changed table cell flashes its row). A line no block covers (blank line, deleted
// text) goes to the nearest block. The first key is the scroll target.
changed_keys :: proc(blocks: []Block, ranges: []Line_Range, allocator := context.allocator) -> []string {
	picked := make([]bool, len(blocks), context.temp_allocator)
	for r in ranges {
		for line in r.first ..= r.last {
			if idx := best_block(blocks, line); idx >= 0 do picked[idx] = true
		}
	}
	out := make([dynamic]string, allocator)
	for p, i in picked {
		if p do append(&out, blocks[i].key)
	}
	return out[:]
}

@(private = "file")
best_block :: proc(blocks: []Block, line: int) -> int {
	best := -1
	best_dist, best_span := max(int), max(int)
	for b, i in blocks {
		dist := 0
		if line < b.first do dist = b.first - line
		else if line > b.last do dist = line - b.last
		span := b.last - b.first
		if dist < best_dist || (dist == best_dist && span < best_span) { // strict: earliest wins ties
			best, best_dist, best_span = i, dist, span
		}
	}
	return best
}

@(private = "file")
parse_sourcepos :: proc(key: string) -> (first, last: int, ok: bool) {
	dash := strings.index_byte(key, '-')
	if dash < 0 do return
	l, r := key[:dash], key[dash + 1:]
	lc, rc := strings.index_byte(l, ':'), strings.index_byte(r, ':')
	if lc < 0 || rc < 0 do return
	f, ok1 := strconv.parse_int(l[:lc])
	e, ok2 := strconv.parse_int(r[:rc])
	if !ok1 || !ok2 do return
	return f, e, true
}
