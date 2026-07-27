## Validates every .gd script and the project's scenes. Run from the repo root:
##   pwsh -File tools/check.ps1
## Set $env:GODOT to the engine binary, or put it on PATH. Use a `_console` build
## on Windows; the plain .exe detaches from the terminal and prints nothing.
##
## Why this exists: `--headless --path . --quit` alone is not a validation step.
## It only parses scripts reachable from the main scene, and it exits 0 even when
## it prints a parse error, so its exit code cannot be gated on.

$ErrorActionPreference = "Stop"

function Resolve-Godot {
	$candidates = if ($env:GODOT) { @($env:GODOT) } else { @("godot_console", "godot", "godot4") }

	foreach ($candidate in $candidates) {
		if (Test-Path -LiteralPath $candidate -PathType Leaf) {
			return (Resolve-Path -LiteralPath $candidate).Path
		}
		$command = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue |
			Select-Object -First 1
		if ($command) {
			return $command.Source
		}
	}

	$hint = if ($env:GODOT) {
		"`$env:GODOT is set to '$env:GODOT', which is not an executable."
	}
	else {
		"No Godot binary found on PATH."
	}
	$Host.UI.WriteErrorLine("$hint Set `$env:GODOT to your engine path, e.g.")
	$Host.UI.WriteErrorLine("  `$env:GODOT = 'C:\path\to\Godot_v4.7-stable_win64_console.exe'")
	exit 2
}

$godot = Resolve-Godot

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
