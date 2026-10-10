# Rebuild vendor/cmark-gfm/lib. Usage (from VS dev shell): .\vendor\build-cmark.ps1 <path-to-cmark-gfm-clone> <build-dir>
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Build)
$ErrorActionPreference = 'Stop'
cmake -S $Src -B $Build -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=Release "-DCMAKE_C_FLAGS_RELEASE=/MT /O2 /DNDEBUG" -DCMARK_STATIC=ON -DCMARK_SHARED=OFF -DCMARK_TESTS=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build $Build
Copy-Item "$Build\src\cmark-gfm_static.lib", "$Build\extensions\cmark-gfm-extensions_static.lib" "$PSScriptRoot\cmark-gfm\lib\"

