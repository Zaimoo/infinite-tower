$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$luau = Join-Path $env:TEMP 'infinite-tower-luau-0.743\luau.exe'
$compiler = Join-Path $env:TEMP 'infinite-tower-luau-0.743\luau-compile.exe'

# 1. First compile all production code to verify 100% clean compilation
$sources = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'src') -Filter '*.luau' -Recurse | ForEach-Object { $_.FullName })
& $compiler --null @sources
if ($LASTEXITCODE -ne 0) { throw 'Production Luau compilation failed.' }

# 2. Run the AFK test suite
$modules = @(
    'ReplicatedStorage/Shared/Config/StatBalance.luau',
    'ReplicatedStorage/Shared/Config/HeroCatalog.luau',
    'ReplicatedStorage/Shared/Config/ArtifactCatalog.luau',
    'ReplicatedStorage/Shared/Config/FacilityConfig.luau',
    'ReplicatedStorage/Shared/Config/PitBalanceConfig.luau',
    'ReplicatedStorage/Shared/Util/AttackTimeline.luau',
    'ReplicatedStorage/Shared/Util/StatFormulas.luau'
)

$bundleParts = [System.Collections.Generic.List[string]]::new()
$bundleParts.Add([System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'roblox-module-shim.luau')))

foreach ($m in $modules) {
    $src = [System.IO.File]::ReadAllText((Join-Path (Join-Path $repoRoot 'src') $m))
    $modName = ($m -replace '\.luau$', '') -replace '/', '.'
    $bundleParts.Add("register('$modName', function(script)`n$src`nend)")
}

$bundleParts.Add([System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'afk-facility.spec.luau')))

$testBundle = Join-Path $env:TEMP 'test-afk.luau'
[System.IO.File]::WriteAllText($testBundle, ($bundleParts -join "`n"), [System.Text.UTF8Encoding]::new($false))
& $luau $testBundle
if ($LASTEXITCODE -ne 0) { throw 'AFK facility tests failed.' }
