# Build marked4win into build\. Run tests first: odin test src
$ErrorActionPreference = 'Stop'
$odin = 'C:\Users\micha\dev\Odin\odin.exe'
New-Item -ItemType Directory -Force "$PSScriptRoot\build" | Out-Null
& $odin build "$PSScriptRoot\src" -out:"$PSScriptRoot\build\marked4win.exe" -subsystem:windows
if ($LASTEXITCODE -ne 0) { throw "odin build failed" }
Copy-Item "$PSScriptRoot\vendor\webview2\WebView2Loader.dll" "$PSScriptRoot\build\" -Force
Remove-Item "$PSScriptRoot\build\assets" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item "$PSScriptRoot\assets" "$PSScriptRoot\build\assets" -Recurse
