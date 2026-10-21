$ErrorActionPreference = 'Stop'
$outDir = $PSScriptRoot
$repoRoot = 'C:\Projects\infinite-tower'
$baseline = 'C:\Users\msi\Documents\ChatGPT\Infinite towers\tower-rebuild-baseline-20261021\studio-script-bodies'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$parts = [System.Collections.Generic.List[string]]::new()
$parts.Add('-- Offline review proofs. Actual extracted blocks are preserved between markers. No Roblox/network calls.')
foreach ($variant in @('repository', 'studio-baseline')) {
    $path = if ($variant -eq 'repository') { Join-Path $repoRoot 'src\ServerScriptService\ExtractionAndSocial\SyndicateService.server.luau' } else { Join-Path $baseline 'ServerScriptService.ExtractionAndSocial.SyndicateService.luau' }
    $body = [System.IO.File]::ReadAllText($path)
    $start = $body.IndexOf('PlotEspionageEvent.OnServerEvent:Connect(function(')
    $finish = $body.IndexOf("`n_G.SyndicateService", $start)
    if ($start -lt 0 -or $finish -lt 0) { throw 'Syndicate handler extraction failed.' }
    $handler = $body.Substring($start, $finish - $start)
    $parts.Add("do -- $variant : $path")
    $parts.Add(@'
local _G = {}
local player = { UserId = 77, DisplayName = 'OfflineTester' }
local function facility() return { LastRuneTimestamp = 0, LastRuneWasLeech = false } end
local profile = { Currencies = { Gold = 0, Gems = 0 }, Social = { Honor = 0, Stats = { LeechesPurged = 0 }, MimicIllusionMode = 'TRUE_STATE' }, Facilities = { Infirmary = facility(), ManaConduit = facility() } }
local Players = { GetPlayerByUserId = function(_, id) return id == player.UserId and player or nil end }
local dm = { GetProfile = function(p) assert(p == player); return profile end, AdjustHonor = function(p, delta) assert(p == player); profile.Social.Honor = math.clamp(profile.Social.Honor + delta, -100, 100) end, SendToast = function() end, BroadcastToast = function() end, SyncProfile = function() end }
local function getDataManager() return dm end
local callback
local PlotEspionageEvent = { OnServerEvent = { Connect = function(_, handler) callback = handler end } }
-- BEGIN ACTUAL EXTRACTED SYNDICATE HANDLER
'@)
    $parts.Add($handler)
    $parts.Add(@'
-- END ACTUAL EXTRACTED SYNDICATE HANDLER
callback(player, 2, nil, 'Infirmary')
callback(player, 2, nil, 'Infirmary')
assert(profile.Currencies.Gems == 50, 'Expected repeat blessing payouts')
assert(profile.Social.Honor == 10, 'Expected repeat blessing honor')
print('PASS: two immediate self-bless calls: +50 Gems, +10 Honor')
local gemsBefore, goldBefore = profile.Currencies.Gems, profile.Currencies.Gold
for _ = 1, 2 do callback(player, 3, nil, 'Infirmary'); callback(player, 4, nil, 'Infirmary') end
assert(profile.Currencies.Gems - gemsBefore == 100, 'Expected repeat self-purge gem payouts')
assert(profile.Currencies.Gold - goldBefore == 1000, 'Expected repeat self-purge gold payouts')
print('PASS: two immediate self-leech/purge pairs: +100 Gems, +1000 Gold')
end
'@)
}
$path = Join-Path $baseline 'ServerScriptService.Core.DataManager.luau'
$body = [System.IO.File]::ReadAllText($path)
$start = $body.IndexOf('-- Auto-migrate legacy SQUAD assignments')
$finish = $body.IndexOf('-- Notify CombatSimulation', $start)
if ($start -lt 0 -or $finish -lt 0) { throw 'Migration extraction failed.' }
$parts.Add("do -- $path")
$parts.Add('local function syncMigration(profile) -- BEGIN ACTUAL EXTRACTED MIGRATION')
$parts.Add($body.Substring($start, $finish - $start))
$parts.Add(@'
end -- END ACTUAL EXTRACTED MIGRATION
local benchProfile = { Heroes = { A = { UUID = 'A', Assignment = 'BENCHED' } }, DeployedSquadOrder = { 'A' } }
syncMigration(benchProfile)
assert(benchProfile.Heroes.A.Assignment == 'SQUAD_SLOT_1')
print('PASS: intended BENCHED A is redeployed into SQUAD_SLOT_1 by stale order')
local swapProfile = { Heroes = { A = { UUID = 'A', Assignment = 'BENCHED' }, B = { UUID = 'B', Assignment = 'SQUAD_SLOT_1' } }, DeployedSquadOrder = { 'A' } }
syncMigration(swapProfile)
assert(swapProfile.Heroes.A.Assignment == 'SQUAD_SLOT_2')
assert(swapProfile.Heroes.B.Assignment == 'SQUAD_SLOT_1')
print('PASS: displaced A is redeployed into empty SQUAD_SLOT_2 after replacing slot 1 with B')
end
'@)
$path = Join-Path $repoRoot 'src\ServerScriptService\Core\DataManager.server.luau'
$body = [System.IO.File]::ReadAllText($path)
$start = $body.IndexOf('local function removeUUIDFromFacilities(')
$finish = $body.IndexOf('-- 6. FACILITY INTERACTIONS', $start)
if ($start -lt 0 -or $finish -lt 0) { throw 'Assignment extraction failed.' }
$parts.Add("do -- $path")
$parts.Add(@'
local hero = { UUID = 'A', Assignment = 'FACILITY_INFIRMARY', ComaUntilTimestamp = 0 }
local profile = { Heroes = { A = hero }, Facilities = { Infirmary = { AssignedHeroUUIDs = { 'A' } } } }
for slot = 1, 5 do profile.Heroes['S' .. slot] = { UUID = 'S' .. slot, Assignment = 'SQUAD_SLOT_' .. slot } end
local player = {}
local ActiveProfiles = { [player] = profile }
local DataManager = { MaxSquadSlots = function() return 5 end, SyncProfile = function() end, SendToast = function() end }
local AssignHeroRoleFunc = {}
-- BEGIN ACTUAL EXTRACTED ASSIGNMENT BLOCK
'@)
$parts.Add($body.Substring($start, $finish - $start))
$parts.Add(@'
-- END ACTUAL EXTRACTED ASSIGNMENT BLOCK
local success, message = AssignHeroRoleFunc.OnServerInvoke(player, 'A', 'SQUAD_AUTO')
assert(success == false)
assert(hero.Assignment == 'FACILITY_INFIRMARY')
assert(#profile.Facilities.Infirmary.AssignedHeroUUIDs == 0)
print('PASS: rejected SQUAD_AUTO removes existing infirmary worker index while preserving assignment: ' .. message)
end
print('All 7 isolated review reproductions passed. These are bug reproductions, not successful gameplay acceptance checks.')
'@)
$proofPath = Join-Path $outDir 'economy-review-proof.luau'
[System.IO.File]::WriteAllText($proofPath, ($parts -join "`n"), $utf8)
& 'C:\Users\msi\AppData\Local\Temp\infinite-tower-luau-0.743\luau.exe' $proofPath | Tee-Object -FilePath (Join-Path $outDir 'economy-review-proof-output.txt')
if ($LASTEXITCODE -ne 0) { throw 'Review proof failed.' }
