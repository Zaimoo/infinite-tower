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
# In batches: every full path on one command line overflows Windows' 32,767-character limit.
for ($first = 0; $first -lt $sources.Count; $first += 100) {
    $batch = $sources[$first..([Math]::Min($first + 99, $sources.Count - 1))]
    & $compiler --null @batch
    if ($LASTEXITCODE -ne 0) { throw 'Production Luau compilation failed.' }
}

# The CLI has no Roblox DataModel. Bundle unchanged module bodies inside loader
# closures, supplying only module lookup and the Color3 constructors used by the
# catalog. The actual math, economy validation and transactions run as shipped.
$modulePaths = @(
    'ReplicatedStorage/Shared/Config/StatBalance.luau',
    'ReplicatedStorage/Shared/Config/TowerHardcoreConfig.luau',
    'ReplicatedStorage/Shared/Config/HeroCatalog.luau',
    'ReplicatedStorage/Shared/Config/ArtifactCatalog.luau',
    'ReplicatedStorage/Shared/Config/WeaponVfxConfig.luau',
    'ReplicatedStorage/Shared/Config/ArchetypeCombatSkills.luau',
    'ReplicatedStorage/Shared/Config/FacilityConfig.luau',
    'ReplicatedStorage/Shared/Config/PitBalanceConfig.luau',
    'ReplicatedStorage/Shared/Util/SupportRules.luau',
    'ReplicatedStorage/Shared/Config/MobCatalog.luau',
    'ReplicatedStorage/Shared/Config/TowerLayout.luau',
    'ReplicatedStorage/Shared/Config/TowerPortalAssets.luau',
    'ReplicatedStorage/Shared/Config/TowerBiomeKit.luau',
    'ReplicatedStorage/Shared/Config/HubLayout.luau',
    'ReplicatedStorage/Shared/Util/HubGrassMask.luau',
    'ReplicatedStorage/Assets/RunesmithMeshes/runesmith_sanctuary.luau',
    'ReplicatedStorage/Assets/RunesmithMeshData.luau',
    'ReplicatedStorage/Assets/GroupChestMeshes/group_chest.luau',
    'ReplicatedStorage/Assets/GroupChestMeshData.luau',
    'ReplicatedStorage/Assets/HubPathMeshes/hub_cobble_paths.luau',
    'ReplicatedStorage/Assets/HubPathMeshData.luau',
    'ReplicatedStorage/Shared/Config/HubLighting.luau',
    'ReplicatedStorage/Shared/Config/RelicConfig.luau',
    'ReplicatedStorage/Shared/Config/SettingsConfig.luau',
    'ReplicatedStorage/Shared/Config/AnimeSfxManifest.luau',
    'ReplicatedStorage/Shared/Config/SoundCatalog.luau',
    'ReplicatedStorage/Shared/Config/TowerFloorConfig.luau',
    'ReplicatedStorage/Shared/Config/FirstBiomeCombat.luau',
    'ReplicatedStorage/Assets/EnemyClips/Common.luau',
    'ReplicatedStorage/Assets/EnemyClips/Bipeds.luau',
    'ReplicatedStorage/Assets/EnemyClips/Colossi.luau',
    'ReplicatedStorage/Assets/EnemyClips/Creatures.luau',
    'ReplicatedStorage/Assets/TowerEnemyClips.luau',
    'ReplicatedStorage/Assets/EnemyAnimator.luau',
    'ReplicatedStorage/Shared/Config/TowerEnemyModelIndex.luau',
    'ReplicatedStorage/Assets/HeroRig/HeroRigSpec.luau',
    'ReplicatedStorage/Assets/HeroRig/HeroSockets.luau',
    'ReplicatedStorage/Assets/HeroRig/HeroCostumeMath.luau',
    'ReplicatedStorage/Assets/HeroRig/HeroCostumes.luau',
    'ReplicatedStorage/Assets/HeroRig/HeroClips.luau',
    'ReplicatedStorage/Assets/HeroRig/HeroBowString.luau',
    'ReplicatedStorage/Shared/Util/HeroActionTiming.luau',
    'ReplicatedStorage/Shared/Config/SkillVfxCatalog.luau',
    'ReplicatedStorage/Assets/CombatVfx/VfxMath.luau',
    'ReplicatedStorage/Shared/Util/AttackTimeline.luau',
    'ReplicatedStorage/Shared/Util/EnemyActionState.luau',
    'ReplicatedStorage/Shared/Util/TowerProtocol.luau',
    'ReplicatedStorage/Shared/Util/TowerRequestPolicy.luau',
    'ReplicatedStorage/Shared/Util/TowerSanctuaryRules.luau',
    'ReplicatedStorage/Shared/Config/ReforgeConfig.luau',
    'ReplicatedStorage/Shared/Util/ReforgeRules.luau',
    'ReplicatedStorage/Shared/Util/StatFormulas.luau',
    'ReplicatedStorage/Shared/Util/WeaponPromotion.luau',
    'ReplicatedStorage/Shared/Util/TowerProgress.luau',
    'ReplicatedStorage/Shared/Util/CampWaves.luau',
    'ReplicatedStorage/Shared/Util/CampRoster.luau',
    'ReplicatedStorage/Shared/Util/PatrolPath.luau',
    'ReplicatedStorage/Shared/Util/AffixRules.luau',
    'ReplicatedStorage/Shared/Config/TowerEventConfig.luau',
    'ReplicatedStorage/Shared/Util/TowerEventRules.luau',
    'ReplicatedStorage/Shared/Config/RaidConfig.luau',
    'ReplicatedStorage/Shared/Util/RaidRules.luau',
    'ReplicatedStorage/Shared/Util/GrimoireIcons.luau',
    'ReplicatedStorage/Shared/Util/TowerRun.luau',
    'ReplicatedStorage/Shared/Util/LootDuel.luau',
    'ReplicatedStorage/Shared/Config/FortressTreeConfig.luau',
    'ReplicatedStorage/Shared/Config/OnboardingConfig.luau',
    'ReplicatedStorage/Shared/Util/OnboardingFunnel.luau',
    'ReplicatedStorage/Shared/Util/NewsRules.luau',
    'ReplicatedStorage/Shared/Config/GuideConfig.luau',
    'ServerScriptService/Core/GuideLessons.luau',
    'ReplicatedStorage/Shared/Util/FrontierIncome.luau',
    'ReplicatedStorage/Shared/Config/ShopConfig.luau',
    'ReplicatedStorage/Shared/Util/FortressTree.luau',
    'ReplicatedStorage/Shared/Util/InventoryCapacity.luau',
    'ReplicatedStorage/Shared/Util/OutskirtsRules.luau',
    'ReplicatedStorage/Shared/Util/PlotQueue.luau',
    'ReplicatedStorage/Shared/Util/FacilityWorkerRules.luau',
    'ReplicatedStorage/Shared/Util/SummonLuck.luau',
    'ReplicatedStorage/Shared/Util/HeroBannerOdds.luau',
    'ReplicatedStorage/Shared/Config/ShopConfig.luau',
    'ReplicatedStorage/Shared/Util/MirrorBanner.luau',
    'ReplicatedStorage/Shared/Util/AnvilBanner.luau',
    'ReplicatedStorage/Shared/Util/PreloadManifest.luau',
    'ReplicatedStorage/Shared/Util/Onboarding.luau',
    'ReplicatedStorage/Shared/Config/PotionConfig.luau',
    'ReplicatedStorage/Shared/Util/PotionRules.luau',
    'ReplicatedStorage/Shared/Config/RewardsConfig.luau',
    'ReplicatedStorage/Shared/Config/BattlePassConfig.luau',
    'ReplicatedStorage/Shared/Util/BattlePassRules.luau',
    'ReplicatedStorage/Shared/Util/RewardRules.luau',
    'ReplicatedStorage/Shared/Util/NotorietyRules.luau',
    'ServerScriptService/Core/RewardCodes.luau',
    'ServerScriptService/Core/ProfileMigrations.luau',
    'ServerScriptService/Core/ProfileCodec.luau',
    'ReplicatedStorage/Shared/Util/PitMath.luau',
    'ServerScriptService/Core/PitService.luau',
    'ReplicatedStorage/Shared/Util/EquipBest.luau',
    'ReplicatedStorage/Shared/Util/UiKitRules.luau',
    'ReplicatedStorage/Shared/Util/LeaderboardRules.luau',
    'ReplicatedStorage/Shared/Util/HeroPickerFilter.luau',
    'ReplicatedStorage/Shared/Util/EffectCullingRules.luau',
    'ReplicatedStorage/Shared/Util/ProfileDelta.luau',
    'ServerScriptService/Core/ForgeTransactions.luau',
    'ServerScriptService/Combat/HeroImpactQueue.luau',
    'ServerScriptService/Combat/HeroSkillEffects.luau',
    'ServerScriptService/Combat/HeroTargeting.luau',
    'ServerScriptService/Combat/HeroCombatMovement.luau',
    'ServerScriptService/Core/TowerTraversal.luau',
    'ServerScriptService/Core/TowerNavigationGraph.luau',
    'ServerScriptService/Core/TowerTerrain.luau',
    'ServerScriptService/Core/TowerSetPieces/InfernalFoundry.luau',
    'ServerScriptService/Core/TowerSetPieces/InfernalFloor24.luau',
    'ServerScriptService/Core/TowerSetPieces/InfernalFloor25.luau',
    'ServerScriptService/Core/TowerSetPieces/ThunderHighlands.luau',
    'ServerScriptService/Core/TowerSetPieces/ThunderFloor27.luau',
    'ServerScriptService/Core/TowerSetPieces/ThunderFloor28.luau',
    'ServerScriptService/Core/TowerSetPieces/ThunderFloor29.luau',
    'ServerScriptService/Core/TowerSetPieces/CorruptedGrove.luau',
    'ServerScriptService/Core/TowerSetPieces/CorruptedFloor32.luau',
    'ServerScriptService/Core/TowerSetPieces/CorruptedFloor33.luau',
    'ServerScriptService/Core/TowerSetPieces/CorruptedFloor34.luau',
    'ServerScriptService/Core/TowerSetPieces/CorruptedFloor35.luau',
    'ServerScriptService/Core/TowerSetPieces/SunkenSanctuary.luau',
    'ServerScriptService/Core/TowerSetPieces/SunkenFloor37.luau',
    'ServerScriptService/Core/NavigationRecovery.luau',
    'ServerScriptService/Core/NavigationQueue.luau',
    'ServerScriptService/Combat/SquadMovement.luau',
    'ServerScriptService/Combat/TowerEncounterRuntime.luau'
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
foreach ($suite in @('settings-persistence.spec.luau', 'pit.spec.luau', 'forge.spec.luau', 'forge-workbench.spec.luau', 'equip-best.spec.luau', 'combat-skills.spec.luau', 'tower.spec.luau', 'tower-transport.spec.luau', 'tower-combat.spec.luau', 'tower-rework.spec.luau', 'phase1-combat-tempo.luau', 'hero-rig.spec.luau', 'phase2-floor-loop.spec.luau', 'phase2-defeat-rules.spec.luau', 'hero-action.spec.luau', 'hero-targeting.spec.luau', 'hero-combat-movement.spec.luau', 'tower-navigation.spec.luau', 'squad-movement.spec.luau', 'combat-vfx.spec.luau', 'phase4-progression.luau', 'profile-persistence.spec.luau', 'tower-run-loop.spec.luau', 'tower-camp-roster.spec.luau', 'tower-support.spec.luau', 'tower-patrols.spec.luau', 'tower-affixes.spec.luau', 'tower-events.spec.luau', 'tower-portals.spec.luau', 'tower-biome-kit.spec.luau', 'tower-layout-variants.spec.luau', 'tower-authored-refactor.spec.luau', 'hublayout.spec.luau', 'plot-queue.spec.luau', 'hub-grass-mask.spec.luau', 'runesmith-sanctuary.spec.luau', 'group-chest.spec.luau', 'hub-cobble-paths.spec.luau', 'leaderboard-redesign.spec.luau', 'outskirts-waves.spec.luau', 'facility-workers.spec.luau', 'relic-biome-config.spec.luau', 'inventory-capacity.spec.luau', 'hero-banner-odds.spec.luau', 'mirror.spec.luau', 'anvil.spec.luau', 'preload-manifest.spec.luau', 'anime-sfx.spec.luau', 'ui-kit.spec.luau', 'hero-picker-filter.spec.luau', 'effect-culling.spec.luau', 'profile-delta.spec.luau', 'raid.spec.luau', 'rewards.spec.luau', 'battlepass.spec.luau', 'onboarding-funnel.spec.luau', 'carry-steal.spec.luau', 'news.spec.luau', 'notoriety.spec.luau', 'enemy-models.spec.luau', 'enemy-clips.spec.luau', 'reforge.spec.luau')) {
    $bundleParts.Add('do local function runSuite()')
    $bundleParts.Add([System.IO.File]::ReadAllText((Join-Path $PSScriptRoot $suite)))
    $bundleParts.Add("`nend`nrunSuite()`nend")
}
# Keep generated tests out of the installed CLI directory, which may be read-only.
$bundlePath = Join-Path $env:TEMP 'infinite-tower-tests.luau'
[System.IO.File]::WriteAllText($bundlePath, ($bundleParts -join "`n"), [System.Text.UTF8Encoding]::new($false))
& $luau $bundlePath
if ($LASTEXITCODE -ne 0) { throw 'Pit/tower regression tests failed.' }
