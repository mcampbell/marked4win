package main

import "core:testing"

@(private = "file")
sig :: proc(mtime: i64, size: i64 = 10) -> File_Sig {
	return {exists = true, mtime = mtime, size = size}
}

@(private = "file")
gone :: File_Sig{}

@(test)
test_watch_unchanged_is_quiet :: proc(t: ^testing.T) {
	w := watch_start(sig(1))
	for _ in 0 ..< 5 {
		testing.expect_value(t, watch_step(&w, sig(1)), Watch_Event.None)
	}
}

@(test)
test_watch_change_reloads_after_one_stable_poll :: proc(t: ^testing.T) {
	w := watch_start(sig(1))
	testing.expect_value(t, watch_step(&w, sig(2)), Watch_Event.None) // still settling
	testing.expect_value(t, watch_step(&w, sig(2)), Watch_Event.Reload)
	testing.expect_value(t, watch_step(&w, sig(2)), Watch_Event.None)
}

@(test)
test_watch_size_change_counts :: proc(t: ^testing.T) {
	w := watch_start(sig(1, 10))
	watch_step(&w, sig(1, 99))
	testing.expect_value(t, watch_step(&w, sig(1, 99)), Watch_Event.Reload)
}

@(test)
test_watch_burst_of_writes_reloads_once :: proc(t: ^testing.T) {
	w := watch_start(sig(1))
	reloads := 0
	for m in ([]i64{2, 3, 4, 5, 5, 5}) {
		if watch_step(&w, sig(m)) == .Reload do reloads += 1
	}
	testing.expect_value(t, reloads, 1)
}

@(test)
test_watch_missing_needs_two_polls :: proc(t: ^testing.T) {
	w := watch_start(sig(1))
	testing.expect_value(t, watch_step(&w, gone), Watch_Event.None)
	testing.expect_value(t, watch_step(&w, gone), Watch_Event.Missing)
	testing.expect_value(t, watch_step(&w, gone), Watch_Event.None) // report once
}

@(test)
test_watch_atomic_save_blip_is_not_missing :: proc(t: ^testing.T) {
	w := watch_start(sig(1))
	testing.expect_value(t, watch_step(&w, gone), Watch_Event.None)
	testing.expect_value(t, watch_step(&w, sig(2)), Watch_Event.None)
	testing.expect_value(t, watch_step(&w, sig(2)), Watch_Event.Reload)
}

@(test)
test_watch_return_same_file_reloads :: proc(t: ^testing.T) {
	w := watch_start(sig(1))
	watch_step(&w, gone)
	watch_step(&w, gone)
	testing.expect_value(t, watch_step(&w, sig(1)), Watch_Event.None) // settling
	testing.expect_value(t, watch_step(&w, sig(1)), Watch_Event.Reload) // clears the banner
}

@(test)
test_watch_start_missing :: proc(t: ^testing.T) {
	w := watch_start(gone)
	watch_step(&w, gone)
	testing.expect_value(t, watch_step(&w, gone), Watch_Event.Missing)
}
