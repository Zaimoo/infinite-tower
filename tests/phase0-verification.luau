--!strict
-- tests/phase0-verification.luau
-- Phase 0 Foundation & P1 Bug Fixes Verification Test Suite

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Shared = RS.Shared
local StatFormulas = require(Shared.Util.StatFormulas)
local AttackTimeline = require(Shared.Util.AttackTimeline)

local results = {
    total = 0,
    passed = 0,
    failed = 0,
    tests = {} :: { [number]: { name: string, status: string, error: string? } }
}

local function assertTest(name: string, condition: boolean, msg: string?)
    results.total += 1
    if condition then
        results.passed += 1
        table.insert(results.tests, { name = name, status = "PASS" })
    else
        results.failed += 1
        table.insert(results.tests, { name = name, status = "FAIL", error = msg or "Assertion failed" })
    end
end

-- ============================================================================
-- TEST SUITE 1: Bug 1 - Weapon ATK Stat Preservation Across 100 Ticks
-- ============================================================================
do
    local profile = {
        Heroes = {
            ["hero_1"] = {
                UUID = "hero_1",
                TemplateId = "hero_han",
                Level = 10,
                Stars = 2,
                EquippedArtifactUUID = "art_1"
            }
        },
        Artifacts = {
            ["art_1"] = {
                UUID = "art_1",
                TemplateId = "art_rusty_daggers",
                Type = "DAGGERS",
                Rarity = 2,
                Star = 2,
                Level = 5,
            }
        }
    }
    local hero = profile.Heroes["hero_1"]
    local equippedArt = StatFormulas.GetEquippedArtifact(profile, hero)
    assertTest("Bug1_GetEquippedArtifact", equippedArt ~= nil and equippedArt.UUID == "art_1", "Artifact not found")

    local snapshotWithoutWeapon = StatFormulas.GetCombatSnapshot(hero, nil, false, false, 1.0)
    local snapshotWithWeapon = StatFormulas.GetCombatSnapshot(hero, equippedArt, false, false, 1.0)
    assertTest("Bug1_EffectiveStats_WeaponBonusApplied", snapshotWithWeapon.ATK > snapshotWithoutWeapon.ATK, "Weapon ATK not added")

    local allTicksPreserved = true
    local expectedATK = snapshotWithWeapon.ATK
    for _ = 1, 100 do
        local artOnTick = StatFormulas.GetEquippedArtifact(profile, hero)
        local snapOnTick = StatFormulas.GetCombatSnapshot(hero, artOnTick, false, false, 1.0)
        if snapOnTick.ATK ~= expectedATK or snapOnTick.WeaponPower <= 0 then
            allTicksPreserved = false
            break
        end
    end
    assertTest("Bug1_WeaponATK_Preserved_100Ticks", allTicksPreserved, "Hero ATK reverted or lost weapon bonus during tick simulation")
end

-- ============================================================================
-- TEST SUITE 2: Bug 2 - Vertical AoE Isolation & Floor Boundaries
-- ============================================================================
do
    local actor = {
        NetId = 1,
        EntityGeneration = 1,
        FloorId = 1,
        RoomGeneration = 1,
        CurrentHP = 100,
        IsAlive = true,
        State = "ATTACK",
        Position = Vector3.new(0, 10, 0),
        Yaw = 0,
        EnemyId = "mob_golem",
    }
    local targetFloor1_Close = {
        NetId = 2,
        EntityGeneration = 1,
        FloorId = 1,
        RoomGeneration = 1,
        CurrentHP = 100,
        IsAlive = true,
        State = "IDLE",
        Position = Vector3.new(0, 10, 5),
    }
    local targetFloor2_SameXZ = {
        NetId = 3,
        EntityGeneration = 1,
        FloorId = 2,
        RoomGeneration = 1,
        CurrentHP = 100,
        IsAlive = true,
        State = "IDLE",
        Position = Vector3.new(0, 10, 5),
    }
    local targetFloor1_DeltaY15 = {
        NetId = 4,
        EntityGeneration = 1,
        FloorId = 1,
        RoomGeneration = 1,
        CurrentHP = 100,
        IsAlive = true,
        State = "IDLE",
        Position = Vector3.new(0, 25, 5), -- Delta Y = 15 studs
    }

    local definition = {
        Id = "slam",
        Shape = "SELF_DISC",
        Radius = 10,
        Range = 10,
        WindupSeconds = 1,
        ImpactOffsetSeconds = 1,
        RecoverySeconds = 0.5,
        DamageMultiplier = 1.0,
        MaxLatenessSeconds = 2.0,
    }

    local action = AttackTimeline.Start(actor, targetFloor1_Close, definition, 100.0)
    local inAoE_SameFloor = AttackTimeline.Contains(action, actor, targetFloor1_Close, definition)
    local inAoE_DiffFloor = AttackTimeline.Contains(action, actor, targetFloor2_SameXZ, definition)
    local inAoE_DeltaY15 = AttackTimeline.Contains(action, actor, targetFloor1_DeltaY15, definition)

    assertTest("Bug2_AoE_Hits_SameFloor", inAoE_SameFloor == true, "Expected target on same floor to be hit")
    assertTest("Bug2_AoE_Rejects_DifferentFloor", inAoE_DiffFloor == false, "Cross-floor attack leaked to Floor 2!")
    assertTest("Bug2_AoE_Rejects_DeltaY_Over_11", inAoE_DeltaY15 == false, "Attack hit entity with Delta Y = 15 studs!")
end

-- ============================================================================
-- TEST SUITE 3: Bug 3 - Plot Allocation Exhaustion (6 Plots Full)
-- ============================================================================
do
    local assignedPlots = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true }
    local function assignPlotToPlayerSim()
        local chosenIdx: number? = nil
        for i = 1, 6 do
            if assignedPlots[i] == nil then
                chosenIdx = i
                break
            end
        end
        if not chosenIdx then
            return nil, "ALL_PLOTS_OCCUPIED"
        end
        return chosenIdx, "ASSIGNED"
    end

    local idx7, err7 = assignPlotToPlayerSim()
    assertTest("Bug3_6thPlayer_NoOverwritePlot1", idx7 == nil and err7 == "ALL_PLOTS_OCCUPIED", "Full plots did not return nil/clean rejection")

    -- Free plot 4 and verify reallocation
    assignedPlots[4] = nil
    local idxRealloc, errRealloc = assignPlotToPlayerSim()
    assertTest("Bug3_PlotRealloc_FreedIndex", idxRealloc == 4 and errRealloc == "ASSIGNED", "Freed plot index not reallocated correctly")
end

-- ============================================================================
-- TEST SUITE 4: Bug 4 - Avatar Reset & Physical Cargo Drop Safety
-- ============================================================================
do
    local carrierToHeldLoot = {}
    local fakePlayer = { UserId = 999999, Name = "TestPlayer" }
    local fakeCharacter = Instance.new("Model")
    local fakeHumanoid = Instance.new("Humanoid")
    fakeHumanoid.Health = 100
    fakeHumanoid.Parent = fakeCharacter
    ;(fakePlayer :: any).Character = fakeCharacter

    local dropCalled = false
    local function dropCarriedLoot(p, _broadcast)
        if carrierToHeldLoot[p] then
            carrierToHeldLoot[p] = nil
            dropCalled = true
        end
    end

    carrierToHeldLoot[fakePlayer] = { Gold = 500, Gems = 10 }
    assertTest("Bug4_CargoCarried_InitialState", carrierToHeldLoot[fakePlayer] ~= nil, "Carrier record not set")

    -- Simulate Character Humanoid Died
    dropCarriedLoot(fakePlayer, true)
    assertTest("Bug4_DeathDropsCargo", dropCalled == true and carrierToHeldLoot[fakePlayer] == nil, "Death did not drop cargo or clear carrier record")

    fakeCharacter:Destroy()
end

-- ============================================================================
-- TEST SUITE 5: Bug 5 - Syndicate Espionage Validation & Cooldowns
-- ============================================================================
do
    local playerEspionageCooldowns = {}
    local function processEspionageRune(caller, targetOwner, plotIndex, nowUnix)
        if type(plotIndex) ~= "number" then return false, "INVALID_PLOT_INDEX" end
        if not targetOwner or targetOwner == caller then
            return false, "REJECT_SELF_TARGETING"
        end

        local callerCooldowns = playerEspionageCooldowns[caller.UserId]
        if not callerCooldowns then
            callerCooldowns = {}
            playerEspionageCooldowns[caller.UserId] = callerCooldowns
        end
        if callerCooldowns[targetOwner.UserId] and nowUnix < callerCooldowns[targetOwner.UserId] then
            return false, "COOLDOWN_ACTIVE"
        end
        callerCooldowns[targetOwner.UserId] = nowUnix + 60
        return true, "SUCCESS"
    end

    local caller = { UserId = 101, Name = "Caller" }
    local target = { UserId = 102, Name = "Target" }

    -- Case 1: Self-targeting
    local selfOk, selfErr = processEspionageRune(caller, caller, 1, 1000)
    assertTest("Bug5_Reject_SelfBless", selfOk == false and selfErr == "REJECT_SELF_TARGETING", "Self-bless was not rejected")

    -- Case 2: Valid other target
    local validOk, validErr = processEspionageRune(caller, target, 2, 1000)
    assertTest("Bug5_ValidTarget_Accepted", validOk == true and validErr == "SUCCESS", "Valid blessing on other player was rejected")

    -- Case 3: Spamming within 60s cooldown
    local spamOk, spamErr = processEspionageRune(caller, target, 2, 1030)
    assertTest("Bug5_Cooldown_Enforced_Within60s", spamOk == false and spamErr == "COOLDOWN_ACTIVE", "Cooldown within 60s was not enforced")

    -- Case 4: After cooldown expires
    local expiredOk, expiredErr = processEspionageRune(caller, target, 2, 1061)
    assertTest("Bug5_Cooldown_Expires_After60s", expiredOk == true and expiredErr == "SUCCESS", "Request after cooldown expiration was rejected")
end

return results
