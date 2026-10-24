param(
    [string]$LuauDirectory = (Join-Path $env:TEMP 'infinite-tower-luau-0.743'),
    [switch]$InstallLuau
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$version = '0.743'
$luau = Join-Path $LuauDirectory 'luau.exe'
$compiler = Join-Path $LuauDirectory 'luau-compile.exe'

if ($InstallLuau -and (-not (Test-Path -LiteralPath $luau))) {
    New-Item -ItemType Directory -Path $LuauDirectory -Force | Out-Null
    $archive = Join-Path $LuauDirectory 'luau.zip'
    Invoke-WebRequest -Uri "https://github.com/luau-lang/luau/releases/download/$version/luau-windows.zip" -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $LuauDirectory -Force
}
if (-not (Test-Path -LiteralPath $luau) -or -not (Test-Path -LiteralPath $compiler)) {
    throw 'Official Luau CLI not found. Run tests\run.ps1 -InstallLuau, or supply -LuauDirectory with luau.exe and luau-compile.exe.'
}

# Compile every production script in its original form. No test loader transforms
# are applied to this check, so malformed production files cannot hide in shims.
$sources = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'src') -Filter '*.luau' -Recurse | ForEach-Object { $_.FullName })
& $compiler --null @sources
if ($LASTEXITCODE -ne 0) { throw 'Production Luau compilation failed.' }

# The CLI has no Roblox DataModel. Bundle unchanged module bodies inside loader
# closures, supplying only module lookup and the Color3 constructors used by the
# catalog. The actual math, economy validation and transactions run as shipped.
$modulePaths = @(
    'ReplicatedStorage/Shared/Config/StatBalance.luau',
    'ReplicatedStorage/Shared/Config/HeroCatalog.luau',
    'ReplicatedStorage/Shared/Config/ArtifactCatalog.luau',
    'ReplicatedStorage/Shared/Config/FacilityConfig.luau',
    'ReplicatedStorage/Shared/Config/PitBalanceConfig.luau',
    'ReplicatedStorage/Shared/Config/MobCatalog.luau',
    'ReplicatedStorage/Shared/Config/TowerLayout.luau',
    'ReplicatedStorage/Shared/Config/TowerFloorConfig.luau',
    'ReplicatedStorage/Shared/Config/FirstBiomeCombat.luau',
    'ReplicatedStorage/Assets/TowerEnemyClips.luau',
    'ReplicatedStorage/Shared/Util/AttackTimeline.luau',
    'ReplicatedStorage/Shared/Util/EnemyActionState.luau',
    'ReplicatedStorage/Shared/Util/TowerProtocol.luau',
    'ReplicatedStorage/Shared/Util/TowerRequestPolicy.luau',
    'ReplicatedStorage/Shared/Util/TowerSanctuaryRules.luau',
    'ReplicatedStorage/Shared/Util/StatFormulas.luau',
    'ReplicatedStorage/Shared/Util/WeaponPromotion.luau',
    'ReplicatedStorage/Shared/Util/PitMath.luau',
    'ServerScriptService/Core/PitService.luau'
)
$bundleParts = [System.Collections.Generic.List[string]]::new()
$bundleParts.Add([System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'roblox-module-shim.luau')))
foreach ($modulePath in $modulePaths) {
    $sourcePath = Join-Path (Join-Path $repoRoot 'src') $modulePath
    $moduleName = ($modulePath -replace '\.luau$', '') -replace '/', '.'
    $bundleParts.Add("register('$moduleName', function(script)")
    $bundleParts.Add([System.IO.File]::ReadAllText($sourcePath))
    $bundleParts.Add("`nend)")
}
foreach ($suite in @('pit.spec.luau', 'forge.spec.luau', 'tower.spec.luau', 'tower-transport.spec.luau', 'tower-combat.spec.luau', 'tower-rework.spec.luau')) {
    $bundleParts.Add('do')
    $bundleParts.Add([System.IO.File]::ReadAllText((Join-Path $PSScriptRoot $suite)))
    $bundleParts.Add("`nend")
}
# Keep generated tests out of the installed CLI directory, which may be read-only.
$bundlePath = Join-Path $env:TEMP 'infinite-tower-tests.luau'
[System.IO.File]::WriteAllText($bundlePath, ($bundleParts -join "`n"), [System.Text.UTF8Encoding]::new($false))
& $luau $bundlePath
if ($LASTEXITCODE -ne 0) { throw 'Pit/tower regression tests failed.' }
