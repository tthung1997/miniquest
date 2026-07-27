## Validates every .gd script and the project's scenes. Run from the repo root:
##   pwsh -File tools/check.ps1
## Set $env:GODOT to override the engine path.
##
## Why this exists: `--headless --path . --quit` alone is not a validation step.
## It only parses scripts reachable from the main scene, and it exits 0 even when
## it prints a parse error, so its exit code cannot be gated on.

$ErrorActionPreference = "Stop"

$godot = if ($env:GODOT) { $env:GODOT } else { "S:\Godot\Godot_v4.7.1-stable_win64_console.exe" }
if (-not (Test-Path $godot)) {
	Write-Error "Godot not found at '$godot'. Set `$env:GODOT to your engine path."
	exit 2
}

$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
$failed = @()

try {
	# 1. Per-script parse check. --check-only exits 1 on a parse error and, unlike
	#    --quit, does not care whether the script is reachable from a scene.
	$scripts = Get-ChildItem -Recurse -Filter *.gd -File |
		Where-Object { $_.FullName -notmatch '\\\.godot\\' }

	foreach ($file in $scripts) {
		$rel = $file.FullName.Substring($root.Length + 1) -replace '\\', '/'
		$out = & $godot --headless --path . --check-only --script "res://$rel" 2>&1 | Out-String
		if ($LASTEXITCODE -ne 0 -or $out -match 'SCRIPT ERROR|Parse Error') {
			$failed += $rel
			Write-Host "FAIL  $rel" -ForegroundColor Red
			Write-Host $out.Trim()
		}
		else {
			Write-Host "ok    $rel"
		}
	}

	# 2. Boot the project so scene loading and autoloads are exercised. The exit
	#    code is unreliable here, so scan the output instead.
	$boot = & $godot --headless --path . --quit 2>&1 | Out-String
	if ($boot -match 'SCRIPT ERROR|Parse Error|Failed loading scene|Cannot load resource') {
		$failed += "project boot"
		Write-Host "FAIL  project boot" -ForegroundColor Red
		Write-Host $boot.Trim()
	}
	else {
		Write-Host "ok    project boot"
	}
}
finally {
	Pop-Location
}

if ($failed.Count -gt 0) {
	Write-Host "`n$($failed.Count) check(s) failed." -ForegroundColor Red
	exit 1
}

Write-Host "`nAll checks passed." -ForegroundColor Green
exit 0
