package main

import "core:os"
import win "core:sys/windows"

main :: proc() {
	if win.FAILED(win.CoInitializeEx(nil, .APARTMENTTHREADED)) do os.exit(1)
	defer win.CoUninitialize()
	if !shell_run() do os.exit(1)
}
