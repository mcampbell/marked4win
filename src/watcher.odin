package main

import "core:os"
import "core:time"

// Polls one file. The state machine is pure: feed it a File_Sig per poll.
// Debounce: a changed file reloads only after it looks the same on two polls in a row.
// An atomic save (file vanishes, then returns) must not show "missing".

POLL_MS           :: 300
MISSING_POLLS     :: 2 // polls without the file before we report it

File_Sig :: struct {
	exists: bool,
	mtime:  i64, // unix ns
	size:   i64,
}

Watch_Event :: enum {
	None,
	Reload,  // content changed, or file came back: re-render
	Missing, // file gone: show status, keep last page
}

Watch :: struct {
	shown:         File_Sig, // what the page shows
	last:          File_Sig, // previous poll
	missing_polls: int,
	missing:       bool, // Missing already reported
}

watch_start :: proc(shown: File_Sig) -> Watch {
	return {shown = shown, last = shown}
}

watch_step :: proc(w: ^Watch, cur: File_Sig) -> Watch_Event {
	defer w.last = cur

	if !cur.exists {
		w.missing_polls += 1
		if w.missing_polls >= MISSING_POLLS && !w.missing {
			w.missing = true
			return .Missing
		}
		return .None
	}
	w.missing_polls = 0

	if cur != w.last do return .None // still changing: wait one more poll
	if cur != w.shown || w.missing {
		w.shown = cur
		w.missing = false
		return .Reload
	}
	return .None
}

file_sig :: proc(path: string) -> File_Sig {
	info, err := os.stat(path, context.temp_allocator)
	if err != nil do return {}
	return {exists = true, mtime = time.to_unix_nanoseconds(info.modification_time), size = info.size}
}
