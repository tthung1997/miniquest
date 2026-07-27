## Validates every .gd script and the project's scenes. Run from the repo root:
##   pwsh -File tools/check.ps1
## The engine is taken from $env:GODOT, or found on PATH. Use a `_console` build
## on Windows; the plain .exe detaches from the terminal and prints nothing, which
## would make the output scanning below silently useless.
##
## Why this exists: `--headless --path . --quit` alone is not a validation step.
## It only parses scripts reachable from the main scene, and it exits 0 even when
## it prints a parse error, so its exit code cannot be gated on.

$ErrorActionPreference = "Stop"

function Resolve-Godot {
	if ($env:GODOT) {
		if (Test-Path -LiteralPath $env:GODOT -PathType Leaf) {
			return (Resolve-Path -LiteralPath $env:GODOT).Path
		}
		$command = Get-Command $env:GODOT -CommandType Application -ErrorAction SilentlyContinue |
			Select-Object -First 1
		if ($command) {
			return $command.Source
		}
		$Host.UI.WriteErrorLine("`$env:GODOT is set to '$env:GODOT', which is not an executable.")
		exit 2
	}

	# Console builds only: the plain Windows .exe writes no output, so it would
	# pass every check below vacuously.
	foreach ($name in @("godot_console", "godot4", "godot")) {
		$command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue |
			Select-Object -First 1
		if ($command) {
			return $command.Source
		}
	}

	$Host.UI.WriteErrorLine("No Godot binary found on PATH. Either add the engine's folder")
	$Host.UI.WriteErrorLine("to PATH as `godot_console`/`godot`, or point `$env:GODOT at it:")
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
