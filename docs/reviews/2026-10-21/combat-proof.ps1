param(
    [string]$LuauDirectory = (Join-Path $env:TEMP 'infinite-tower-luau-0.743')
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$productionPath = Join-Path $repoRoot 'src/ServerScriptService/Combat/CombatSimulation.server.luau'
$production = [System.IO.File]::ReadAllText($productionPath)
$parts = [System.Collections.Generic.List[string]]::new()
$parts.Add([System.IO.File]::ReadAllText((Join-Path $repoRoot 'tests/roblox-module-shim.luau')))

# Load the real current formula/catalog bodies without changing their contents.
foreach ($modulePath in @(
    'ReplicatedStorage/Shared/Config/HeroCatalog.luau',
    'ReplicatedStorage/Shared/Config/ArtifactCatalog.luau',
    'ReplicatedStorage/Shared/Config/PitBalanceConfig.luau',
    'ReplicatedStorage/Shared/Util/StatFormulas.luau'
)) {
    $moduleName = ($modulePath -replace '\.luau$', '') -replace '/', '.'
    $parts.Add("register('$moduleName', function(script)")
    $parts.Add([System.IO.File]::ReadAllText((Join-Path (Join-Path $repoRoot 'src') $modulePath)))
    $parts.Add("`nend)")
}

function Get-ExactStatement([string]$pattern) {
    $match = [regex]::Match($production, $pattern)
    if (-not $match.Success) { throw "Production statement not found: $pattern" }
    return $match.Value
}

# Extract the call sites and assignments from production. The proof does not
# recreate CombatSimulation or execute any server event/gameplay lifecycle.
$resolveArtifact = Get-ExactStatement 'local artifact = heroData\.EquippedArtifactUUID and profile\.Artifacts and profile\.Artifacts\[heroData\.EquippedArtifactUUID\]'
$rebuildCall = Get-ExactStatement 'local effATK, effHP, _, effInterval = StatFormulas\.GetEffectiveCombatStats\(heroData, false, false, artifact\)'
$tickBlock = Get-ExactStatement '(?s)if profile and profile\.Heroes\[simHero\.HeroUUID\] then\s+local effATK, effHP, _ = StatFormulas\.GetEffectiveCombatStats\(profile\.Heroes\[simHero\.HeroUUID\], false, false\)\s+simHero\.EffectiveATK = effATK\s+simHero\.MaxHP = effHP\s+end'
$horizontalDistance = Get-ExactStatement '(?s)local function getHorizontalDistance\(a: Vector3, b: Vector3\): number\s+local dx = a\.X - b\.X\s+local dz = a\.Z - b\.Z\s+return math\.sqrt\(dx \* dx \+ dz \* dz\)\s+end'
$elitePredicate = Get-ExactStatement 'if getHorizontalDistance\(simHero\.Position, mob\.Position\) <= mob\.AoERadius then'

$parts.Add(@'
local StatFormulas = require(nodes["ReplicatedStorage.Shared.Util.StatFormulas"])
local HeroCatalog = require(nodes["ReplicatedStorage.Shared.Config.HeroCatalog"])
local ArtifactCatalog = require(nodes["ReplicatedStorage.Shared.Config.ArtifactCatalog"])
local seed = HeroCatalog.Seeds.hero_han
local heroData = {
    TemplateId = seed.HeroId, Archetype = seed.Archetype,
    Stars = 1, Level = 1, QualityScalar = 1,
    BaseATK = seed.NativeATK, BaseHP = seed.NativeHP,
    AttackInterval = seed.AttackInterval, CurrentStamina = 100,
    ComaUntilTimestamp = 0, InheritedImprints = {}, EquippedArtifactUUID = "weapon",
}
local profile = { Heroes = { hero = heroData }, Artifacts = {} }
local simHero = { HeroUUID = "hero", EffectiveATK = 0, MaxHP = 0, AttackInterval = 0 }
local cases = 0
for star = 1, 7 do
    for rarity = 1, 16 do
        profile.Artifacts.weapon = { Star = star, Rarity = rarity }
'@)
$parts.Add($resolveArtifact)
$parts.Add($rebuildCall)
$parts.Add(@'
        simHero.EffectiveATK = effATK
        simHero.MaxHP = effHP
        simHero.AttackInterval = effInterval
        local rebuildATK = simHero.EffectiveATK
        local rebuildInterval = simHero.AttackInterval
'@)
$parts.Add($tickBlock)
$parts.Add(@'
        local artifactATK = ArtifactCatalog.CalculateEffectiveStats(star, rarity)
        assert(rebuildATK - simHero.EffectiveATK == artifactATK, "Expected exact artifact ATK loss")
        assert(simHero.AttackInterval == rebuildInterval, "Tick unexpectedly changed stored attack interval")
        if star == 1 and rarity == 1 then
            print(string.format("EQUIPMENT_SAMPLE hero=hero_han star=%d rarity=%d rebuildATK=%d tickATK=%d lostATK=%d retainedInterval=%.6f",
                star, rarity, rebuildATK, simHero.EffectiveATK, artifactATK, rebuildInterval))
        end
        cases += 1
    end
end
print(string.format("PASS equipped ATK loss reproduced for all %d star/rarity combinations using extracted current production call sites", cases))
'@)
$parts.Add($horizontalDistance)
$parts.Add(@'
local mob = { Position = { X = 10, Y = 0, Z = 20 }, AoERadius = 22 }
simHero.Position = { X = 10, Y = 100, Z = 20 }
local hit = false
'@)
$parts.Add($elitePredicate)
$parts.Add(@'
    hit = true
end
assert(hit, "Expected current elite predicate to hit vertically distant hero")
print("PASS elite damage predicate accepts hero 100 studs above elite at same X/Z; horizontalDistance=0 AoERadius=22")
print("LIMITS: isolated CLI proof of actual formula/catalog bodies and extracted production statements; not an end-to-end Studio playtest")
'@)

$bundlePath = Join-Path $env:TEMP 'infinite-tower-combat-review-proof.luau'
[System.IO.File]::WriteAllText($bundlePath, ($parts -join "`n"), [System.Text.UTF8Encoding]::new($false))
$cliPath = Join-Path $LuauDirectory 'luau.exe'
$output = @(& $cliPath $bundlePath 2>&1)
$exitCode = $LASTEXITCODE
$output | ForEach-Object { Write-Output $_ }
$evidencePath = Join-Path $PSScriptRoot 'combat-proof.txt'
[System.IO.File]::WriteAllLines($evidencePath, [string[]]$output, [System.Text.UTF8Encoding]::new($false))
if ($exitCode -ne 0) { throw "Combat proof failed with exit code $exitCode" }
