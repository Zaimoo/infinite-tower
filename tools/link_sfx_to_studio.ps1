<#
.SYNOPSIS
    Creates directory junctions from each Roblox Studio installation's
    content\sfx directory to the repository's assets\sfx directory so
    rbxasset://sfx/<category>/<slug>.wav loads immediately in Studio Playtest.
#>
[CmdletBinding()]
param(
	[string]$RepoRoot = '',
	[string]$VersionsRoot = (Join-Path $env:LOCALAPPDATA 'Roblox\Versions')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
	$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
	$RepoRoot = Split-Path -Parent $scriptDir
}

$sourceSfxDir = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot 'assets\sfx'))
if (-not (Test-Path -LiteralPath $sourceSfxDir)) {
	throw "Repo assets/sfx directory not found: $sourceSfxDir"
}

if (-not (Test-Path -LiteralPath $VersionsRoot)) {
	Write-Warning "Roblox Versions root not found: $VersionsRoot"
	exit 0
}

$studioVersionDirs = Get-ChildItem -LiteralPath $VersionsRoot -Directory | Where-Object {
	(Test-Path -LiteralPath (Join-Path $_.FullName 'RobloxStudioBeta.exe')) -or
	(Test-Path -LiteralPath (Join-Path $_.FullName 'content'))
}

if (-not $studioVersionDirs) {
	Write-Warning "No Roblox Studio / Roblox client content directories found under $VersionsRoot"
	exit 0
}

$linkedCount = 0
foreach ($verDir in $studioVersionDirs) {
	$contentDir = Join-Path $verDir.FullName 'content'
	if (-not (Test-Path -LiteralPath $contentDir)) {
		continue
	}

	$linkPath = Join-Path $contentDir 'sfx'
	$item = Get-Item -LiteralPath $linkPath -Force -ErrorAction SilentlyContinue
	if ($item) {
		$isReparse = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
		if ($isReparse) {
			$target = $item.Target | Select-Object -First 1
			if ($target -and ([System.IO.Path]::GetFullPath($target) -eq $sourceSfxDir)) {
				Write-Host "Already linked: $linkPath -> $sourceSfxDir"
				$linkedCount++
				continue
			}
			# Repoint existing junction/symlink
			cmd /c rmdir "`"$linkPath`"" | Out-Null
		} else {
			$childCount = @(Get-ChildItem -LiteralPath $linkPath -Force).Count
			if ($childCount -eq 0) {
				Remove-Item -LiteralPath $linkPath -Force
			} else {
				$backupPath = "${linkPath}_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
				Write-Warning "Existing non-empty directory at $linkPath; moving to $backupPath"
				Move-Item -LiteralPath $linkPath -Destination $backupPath -Force
			}
		}
	}

	New-Item -ItemType Junction -Path $linkPath -Target $sourceSfxDir | Out-Null
	Write-Host "Linked: $linkPath -> $sourceSfxDir"
	$linkedCount++
}

Write-Host "Completed Studio content/sfx linking ($linkedCount version(s) linked)."
