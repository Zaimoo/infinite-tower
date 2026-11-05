param([string]$LuauDirectory = (Join-Path $env:TEMP 'infinite-tower-luau-0.743'))
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$cli = Join-Path $LuauDirectory 'luau.exe'
$compiler = Join-Path $LuauDirectory 'luau-compile.exe'
$sourcePaths = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.luau' -Recurse | ForEach-Object FullName)
& $compiler --null @sourcePaths
if ($LASTEXITCODE -ne 0) { throw 'Forge package compilation failed.' }
# Reuse the repository's real catalog/stat module loaders and run its regression suite.
$baselineLog = Join-Path $env:TEMP 'forge-workbench-baseline.log'
& (Join-Path $repoRoot 'tests/run.ps1') -LuauDirectory $LuauDirectory *> $baselineLog
if (-not $?) { Get-Content -LiteralPath $baselineLog -Tail 30; throw 'Repository regression suite failed.' }
$parts = [System.Collections.Generic.List[string]]::new()
$parts.Add([System.IO.File]::ReadAllText((Join-Path $env:TEMP 'infinite-tower-tests.luau')))
$parts.Add('function game:GetService(name) if name == "Workspace" then return {GetServerTimeNow = function() return 1000 end} end return node(name) end')
foreach ($entry in @(
    @{ Name = 'ForgeWorkbench.Types'; Path = 'ForgeWorkbench/Types.luau' },
    @{ Name = 'ForgeWorkbench.Model'; Path = 'ForgeWorkbench/Model.luau' },
    @{ Name = 'Fixture'; Path = 'Fixture.luau' },
    @{ Name = 'DemoTransport'; Path = 'DemoTransport.luau' }
)) {
    $parts.Add("register('ReplicatedStorage.ForgeReview.$($entry.Name)', function(script)")
    $parts.Add([System.IO.File]::ReadAllText((Join-Path $PSScriptRoot $entry.Path)))
    $parts.Add("`nend)")
}
$parts.Add([System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'workbench.spec.luau')))
$bundlePath = Join-Path $env:TEMP 'forge-workbench-tests.luau'
[System.IO.File]::WriteAllText($bundlePath, ($parts -join "`n"), [System.Text.UTF8Encoding]::new($false))
$logPath = Join-Path $env:TEMP 'forge-workbench-tests.log'
& $cli $bundlePath *> $logPath
if ($LASTEXITCODE -ne 0) { Get-Content -LiteralPath $logPath -Tail 40; throw 'Forge workbench tests failed.' }
Get-Content -LiteralPath $logPath | Select-String -Pattern 'forge-workbench:|Forge workbench:'
Write-Output "Repository regression suite passed. Full log: $logPath"
