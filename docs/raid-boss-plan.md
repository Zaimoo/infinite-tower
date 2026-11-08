# Raid Boss System: Implementation Plan

Status: **planned** (models done, code not started). Owner: Zaimoo. Written 2026-11-08.

Every 30 minutes a **Raid Boss** spawns in its own off-map arena. A **Raid Portal** in the Cloister Commons opens a minute before. Masters walk through it with their deployed squad. Inside, the HUD's Right Rail becomes a live **damage leaderboard**, and a **Leave** button appears at the bottom centre, just above the Squad Status card. The fight lasts 5 minutes. When it ends, every participant gets Gems by how much damage they dealt, up to **2,000**.

When this ships, `docs/GAME_DESIGN.MD` gets a new §5.6 *Raid Bosses*, plus updates to §3.5 (portal), §4.6 (HUD), §8.1 (raid floor id) and §2 (loops).

---

## 1. Player flow

```
CALM (~29 min) ──► WARNING (60 s) ──► ACTIVE (300 s) ──► RESULTS (12 s) ──► CALM
 portal dormant     portal flares,      boss fights,        results card,       everyone back
 "Next raid 23:41"  toast to server,    entry stays open,   Gems paid,          in the hub
                    entry opens:        leaderboard live    auto-return
                    staging pad
```

1. **Calm.** The portal stands dormant: dark vortex, dim runes, and a billboard counting down to the next raid along with the next boss's name and icon.
2. **Warning (T−60 s).** The server-wide toast reads "*Vorthak, the Hollow King* rises in 60 s. The Raid Portal is open!" The portal flares in the boss's colour and its `Enter Raid` prompt switches on. Entering now puts the Master and squad on the arena's **staging pad**, which is `CombatSafe`. The boss stays dormant on its dais behind a barrier.
3. **Active (T to T+300 s).** The barrier drops and the boss wakes. You can join late at any point until the last 30 s. Your damage starts counting when you arrive. Boss HP grows as players join (§4).
4. **End.** The fight ends when the boss dies or at T+300 s, whichever comes first. If it survives, it roars and fades away. Each participant gets a results card (rank, damage, share, Gems, Gold), and rewards are paid at once. After 12 s everyone left in the arena returns to the hub at the portal's landing.
5. **Leave.** The Leave button returns you to the hub straight away. Damage already dealt still counts, and rewards still pay at the end as long as you are in the server.

**Entry rules** (checked on the server when the portal prompt fires):
- Onboarding step 2 is done (Tower unlocked), and the Master has at least one deployed hero who is not in `COMA`.
- The Master is not mid-transition, not carrying a relic, not in a duel and not flagged `[Loot Thief]`.
- A squad currently assigned to a tower floor is recalled first. The raid takes the whole active squad along with the Master, combining `ASSIGN` and `VISIT` into one transition.

## 2. Schedule

- **Wall-clock aligned:** a raid starts at every :00 and :30 UTC (`os.time() // 1800 * 1800 + 1800`). Every server shares the cadence, so "next raid in 12:04" is the same everywhere and players can plan around it.
- **Boss rotation:** `bossIndex = (raidNumber % 4) + 1`, where `raidNumber = startTime // 1800`. All four bosses come up every two hours, in a fixed and predictable order.
- **Studio:** setting `workspace.RaidForce = "<BossId>"` starts that boss's warning immediately, mirroring `TowerEventForce`. `workspace.RaidFast = true` shortens the timings to 5 s / 30 s.
- **No players with a squad:** the cycle still runs, so the portal and timers stay honest, but no boss is spawned and no room is allocated.

State is published as `ReplicatedStorage` attributes, like the timed tower events, so late joiners pick it up without a remote:

| Attribute | Value |
| --- | --- |
| `RaidPhase` | `"CALM" \| "WARNING" \| "ACTIVE" \| "RESULTS"` |
| `RaidBossId` | upcoming or running boss id (`HOLLOW_KING`, …) |
| `RaidStartsAt` / `RaidEndsAt` | server times (`Workspace:GetServerTimeNow()` basis) |
| `RaidNumber` | `startTime // 1800`, used as the idempotency key for rewards |

Boss HP is not an attribute: it rides the boss's entity record and the boss banner.

## 3. The four bosses

Each boss uses the existing telegraph shapes (`AttackTimeline`: `ARC`, `SELF_DISC`, `TARGET_DISC`, `PROJECTILE`), so `TowerEncounterRuntime` and the client telegraph renderer need no new shapes. Every boss has a **Phase 2 enrage at 50% HP *or* at 3:00 elapsed**, whichever comes first (+25% attack speed, new signature move), and a **Punish Window** after each signature (+25% damage taken for 4 s, the same rule as Biome Bosses, §5.3).

| Id | Name | Silhouette | Palette | Basic | Signatures | Enrage move |
| --- | --- | --- | --- | --- | --- | --- |
| `HOLLOW_KING` | **Vorthak, the Hollow King** | 34-stud armoured knight-king, crown, tattered cape, flame-bladed greatsword | black iron, crimson, gold | Greatsword Cleave (`ARC`, 14 studs) | Royal Decree (`TARGET_DISC` ×3), Throne Quake (`SELF_DISC`, 24) | Crimson Execution: a sweeping 270° `ARC` |
| `THOUSAND_EYED` | **Ozrith, the Thousand-Eyed** | floating eye, 8 tentacles, two rune halo rings, 4 orbiting eyelets | void purple, flesh, teal | Gaze Bolt (`PROJECTILE`) | Eye Rain (`TARGET_DISC` ×5 small), Void Pulse (`SELF_DISC`, 22) | Unblinking Ray: a slow-tracking `PROJECTILE` corridor that lasts 3 s |
| `BROODMOTHER` | **Xal'Zhara, the Rift Broodmother** | giant spider: rift-crystal abdomen, 8 legs, fangs, 8 eyes | bone, chitin, toxic green | Fang Strike (`ARC`, 10 studs) | Venom Spit (`TARGET_DISC`), Web Burst (`SELF_DISC`, 20) | Brood Swarm: spawns 6 Rift Spiderlings (Regular tier) |
| `SHARDBOUND` | **Aurelith, the Shardbound Colossus** | knuckle-walking crystal golem, crystal back ridge, glowing chest core | dark stone, cyan crystal, gold veins | Crystal Slam (`ARC`, 12 studs) | Shard Volley (`PROJECTILE` ×3 fan), Prism Quake (`SELF_DISC`, 26) | Core Overload: its chest core becomes the only weak point (×2 damage), and a quake fires every 6 s |

**Rigs.** The bosses are modelled in Blender as rigid **segments** (one mesh per limb), each with its origin at its joint pivot. A Roblox builder (`RaidBossRigs`) welds them with named `Motor6D`s, matching how `TowerEnemyRigs` articulates the tower enemies, and animates them procedurally (`RaidBossClips`: idle, walk, attack, cast, enrage, death). This needs no uploaded skinned meshes or `Animation` assets.

## 4. Boss HP and damage

Masters' Squad Power ranges from tiny to astronomical, so raid HP is computed from the people who actually show up.

- **HP budget:** `MaxHP = Σ (squadDPS_i × 300 × HpFactor)` over every participant, with `HpFactor = 0.75`. `squadDPS` comes from `StatFormulas.GetCombatSnapshot`, summed over the deployed heroes (the same source as Squad Power), and has a floor of `RaidConfig.MinDPS`.
- **Late joiners** add their share while the HP *fraction* stays the same: `newMax = oldMax + share`, then `CurrentHP = newMax × oldFraction`. A big squad joining at the end cannot make a dying boss heal to full.
- **Leavers** do not remove HP, so leaving early cannot be used to make the boss weaker.
- **Damage attribution:** in `CombatSimulation`'s hero impact path (the `if mob then` branch near `mob.CurrentHP = math.max(0, mob.CurrentHP - damage)`), raid bosses record **`actualDamage`**, which is capped at the HP remaining, into `RaidService.RecordDamage(userId, actualDamage)`. Overkill is never counted. Damage is only ever measured on the server.
- **Defence:** the boss takes all hero damage normally, Overdrive included. Duel damage and bounty prompts are disabled in the raid room (`DuelArena` and `ReportRelicPickup` early-out on the raid floor id).
- **Hero downs:** signature hits put heroes into `COMA` as usual. A full squad wipe sends the Master back to the hub, and the damage already dealt still counts.

## 5. Rewards

Paid once per raid per player, keyed by `RaidNumber`, when the raid ends (death or timeout).

```
qualifies  = damage_i >= 0.5% of MaxHP   (or top 10 on the board)
share_i    = damage_i / maxDamage        (the top damager has share 1)
kill       = 0.5 + 0.5 × (fraction of boss HP removed)   (1.0 on a kill)
Gems_i     = min(2000, round(2000 × kill × (0.10 + 0.90 × share_i ^ 0.6)))
Gold_i     = round(Gems_i × 25 × floorScale(HighestClearedFloor_i))
```

- **Higher damage always means better rewards.** The curve is monotonic in damage. The `^0.6` softens the gap, so second place with half the top damage still gets about 69% of the top reward.
- **The 2,000 Gem cap** is `RaidConfig.MaxGems`. It is enforced in `RaidRules.Reward` *and* clamped again in `RaidService` before `DataManager` credits the Gems.
- **Kill bonus:** only a boss **kill** pays the full 2,000 to the top damager. A timeout pays between 50% and 99%, depending on how much HP was removed.
- **Participation floor:** anyone who qualifies gets at least 10% (200 Gems on a kill).
- **Extras on a kill:** the top 3 each get a guaranteed **Cursed Urn** relic credited straight to the bank (raids drop no physical loot, so there is nothing to carry). The top damager has a 10% chance at a **Calamity Heart** instead.
- **Economy check:** 2,000 Gems every 30 min is at most 4,000 Gems an hour for the best raider, which sits inside the farming target of 2,900–12,700 an hour (§5.5). Raids are a strong bonus, not a replacement for climbing.

| Damage share of top | Kill | Timeout at 60% HP removed |
| --- | --- | --- |
| 100% (rank 1) | 2,000 | 1,600 |
| 50% | 1,388 | 1,110 |
| 25% | 984 | 787 |
| 5% | 498 | 399 |
| any qualifier | ≥ 200 | ≥ 160 |

## 6. Hub portal

- **Placement:** on the north band at the centre, hub-local `(0, -500)`, facing south (+Z) across the void. It is visible from the Wayfinder Dais, the island and both long bands, and stands between the Plot 5 and Plot 6 landings (x ±142). This becomes `HubLayout.RaidPortal = { X = 0, Z = -500, Yaw = 0 }`, with a matching `CloisterBuilder` clearance so the flower beds and benches move aside. The landing pad back from the raid is the 30-stud plaza in front of it.
- **Model:** `assets/models/raid/portal/` (Blender source `assets-source/raid/RaidPortal.blend`). It is a gothic obsidian arch, 32 studs tall and 26 wide, with horns, a skull keystone, gold trim, twin side pylons with crystal crowns, a stepped dais, a crimson rune channel, and floating shards. Like `TowerPortalAssets`, it has one mesh per role so code can tint the glowing parts: `Frame` (stone, gold and bone on the shared palette texture), `Runes` (Neon, crimson, plus a separate orange mesh for the brazier fire), `Vortex` (a Neon membrane in two layers) and `Shards` (Neon crystals spun by the client). Code recolours `Runes`, `Vortex` and `Shards` to the next boss's accent.
- **Code:** `RaidPortalAssets` (MeshIds and sizes, as in `TowerPortalAssets`) plus a `RaidPortalKit` builder with a part-built fallback while the MeshIds are empty. The client-side `RaidPortalController` handles state visuals: the dormant/warning/active vortex colour, shard orbit speed, the beam, and the billboard countdown (`RaidPhase` attributes). Its `ProximityPrompt` reads "Enter Raid". The server validates distance, phase and the entry rules in §1.

## 7. Raid arena

- **Location:** off-map at `(-14000, 1000, -14000)`, well away from the tower grid (x, z ≥ 12,000). It is one shared room per server.
- **Floor id:** `RaidLayout.FloorId = 60`. The v2 room protocol stores `FloorId` as a u8, so 60 fits. Floors 1–50 stay the tower, and `TowerFloorService.EnsureRoom` gets a raid adapter (`RegisterAdapter("RAID", …)`). Every `FloorId <= 50` check in tower-only code (floor selector, Rift Attunement, kill progress, relic drops, onboarding `FloorCleared`) must exclude 60.
- **Shape:** a 320-stud circular arena built by `RaidArenaBuilder`. The boss dais is in the north half. The staging pad (`CombatSafe`, the return portal, 30 studs deep) sits at the south edge behind a barrier that drops at T. Each boss reskins the arena with its palette, matching the per-biome themes in `TowerRoomBuilder`.
- **Lighting:** a fifth preset, **Raid** (`HubLighting`/`TowerAtmosphereController`), tinted by the boss: crimson for the King, violet for Ozrith, green for the Broodmother, cyan for Aurelith.

## 8. HUD

All of this lives in the React HUD (`Hud/HudApp.luau`), driven by `Store.Raid` (`{ Phase, BossId, EndsAt, InRaid, Board, Self }`).

- **Right Rail becomes the damage leaderboard.** While `Store.Raid.InRaid`, `HudApp` renders `RaidHud.Leaderboard` in the Right Rail's exact rectangle (`rightTop` to `rightBottom`, right-anchored at `L.Edge`) instead of `rail("RightRail", …)`. Each row shows rank, a crown on #1, the avatar headshot, the display name, abbreviated damage, a share bar and a %. Your own row is highlighted. When you are outside the top 8, your row is pinned at the bottom under a divider ("…  #14  You  1.2M"). Rows tween to new positions when the order changes. The header reads "DAMAGE" with the countdown `4:12`.
  - The **Q / E whistle hotkeys keep working** (Overdrive matters for Punish Windows), and a compact 2-chip whistle strip sits under the leaderboard header. The `[TOWER]` button is hidden.
- **Leave button: bottom centre, above the Squad Status card.** It is anchored at `(0.5, 1)` with `Y = -(L.Edge + Components.DrawerHeight(drawerOpen or layoutOpen, cardHeight) + 12)`. It is computed from the drawer height, the same way `currencyBottom` is, so it tracks the drawer's expand and collapse slide and always sits just above it. Clicking it opens a confirm toast ("Leave the raid? Your damage still counts."), then sends `RaidRemotes.Leave`. The top-right **Return to Hub** button is hidden in the raid, so Leave is the only exit.
- **Boss banner:** the existing top-centre `FloorBossTopBanner` is reused with `"RAID BOSS — VORTHAK, THE HOLLOW KING  [PHASE 2: ENRAGED]"`, the HP bar, and the countdown on the right.
- **Hub badge:** in the hub, the timed-event badge slot shows a "Raid in 12:04" chip (or "RAID OPEN" during the warning and active phases). Clicking it pings the portal's location with a world beam.
- **Results card:** a modal in the overlay portal showing rank, damage, share, Gems, Gold and any Urn or Heart, with a "Returning in 10…" countdown.

## 9. Networking

| Remote | Direction | Payload | Notes |
| --- | --- | --- | --- |
| `RaidRemotes.Enter` | C→S | none (the server uses the prompt) | Driven by the `ProximityPrompt` on the server. No client-supplied position is trusted |
| `RaidRemotes.Leave` | C→S | none | Rate-limited to one call per 2 s. It is ignored unless the player is in the raid room |
| `RaidRemotes.Board` | S→C, unreliable, 2 Hz | buffer: `u8 count`, then per row `u8 slot, f64 damage`, then `u8 selfRank, f64 selfDamage, f64 totalDamage, f64 maxHP` | Sent only to the raid room's players. `slot` maps to a per-raid `{ UserId, DisplayName }` roster sent reliably once on join |
| `RaidRemotes.Roster` | S→C, reliable | `{ [slot]: { UserId, Name } }` | Sent on each join |
| `RaidRemotes.Result` | S→C, reliable | `{ Rank, Damage, Share, Gems, Gold, Relics }` | Sent once per raid |

Boss position, HP permille and state ride the normal v2 room entity records for floor 60. Damage popups and telegraphs reuse `CombatVFX` and `TowerAction`.

## 10. Save data

Profiles are not persisted yet (the DataStore is wired but sessions run unsaved), but the shape should be right from day one:

```lua
profile.Raid = { LastRewardedRaid = 0, BestDamage = 0, Kills = 0, Participations = 0 }
```

This needs a migration in `DataManager.SyncProfile` and in `ProfileMigrations`. `LastRewardedRaid` makes the payout idempotent: a reward for `RaidNumber <= LastRewardedRaid` is skipped.

## 11. Files

**New**

| File | Purpose |
| --- | --- |
| `Shared/Config/RaidConfig.luau` | timings, `MaxGems = 2000`, HP factor, reward constants, and the 4 boss definitions (name, title, palette, attacks, enrage, rig spec id) |
| `Shared/Config/RaidPortalAssets.luau` | portal piece MeshIds and sizes |
| `Shared/Config/RaidBossAssets.luau` | per-boss segment MeshIds and sizes, plus joint pivots (from `assets/models/raid/<boss>/<boss>_rig.json`) |
| `Shared/Util/RaidRules.luau` | pure logic: schedule math, boss rotation, HP budget and join scaling, the reward curve and cap, ranking with ties broken by who reached the damage first |
| `ServerScriptService/Raid/RaidService.server.luau` | cycle, attributes, entry and exit, room allocation, damage ledger, payout |
| `ServerScriptService/Raid/RaidArenaBuilder.luau` | arena geometry and themes |
| `ServerScriptService/Raid/RaidPortalKit.luau` | hub portal (mesh or part fallback) and prompt |
| `ServerScriptService/Raid/RaidBossBrain.luau` | boss attack selection, phases and enrage, built on `TowerEncounterRuntime` telegraphs |
| `ReplicatedStorage/Assets/RaidBossRigs.luau` + `RaidBossClips.luau` | segment rig builder and procedural animation |
| `StarterPlayerScripts/UI/Hud/RaidHud.luau` | Leaderboard, LeaveButton, ResultsCard, HubBadge |
| `StarterPlayerScripts/Rendering/RaidPortalController.luau` (+ runtime) | portal state visuals |
| `tests/raid.spec.luau` | `RaidRules` tests |

**Touched:** `CombatSimulation` (damage hook, raid-floor guards), `TowerFloorService` (raid adapter, floor-60 context), `TowerProtocol` (no change, but documented), `HudApp` (rail swap, Leave, badge), `HUDController` (banner text), `CloisterBuilder` / `HubLayout` (portal slot), `DataManager` (migration, payout), `HubLighting` (Raid preset), `docs/GAME_DESIGN.MD`.

## 12. Build order

Each step is its own PR.

1. **Rules and config:** `RaidConfig` and `RaidRules`, plus `tests/raid.spec.luau` (schedule alignment, rotation, HP scaling on join, reward curve, the 2,000 cap, ties, qualification).
2. **Portal in the hub:** `RaidPortalAssets` and `RaidPortalKit`, the `HubLayout` slot, the `CloisterBuilder` clearance, `RaidPortalController`, and the `RaidPhase` attributes with a stub cycle.
3. **Arena and travel:** `RaidArenaBuilder`, floor id 60 in `TowerFloorService`, the enter and leave transitions with the squad, and the auto-return.
4. **Boss combat:** `RaidBossRigs` with the part fallback first, `RaidBossBrain`, the damage hook, HP scaling, then the boss banner.
5. **HUD:** the leaderboard rail swap, the Leave button, the results card and the hub badge.
6. **Rewards and save:** the payout, the `profile.Raid` migration, relic extras and toasts.
7. **Meshes:** upload the Blender FBXs (portal and 4 bosses), fill in the MeshIds, check scale and pivots in Studio.
8. **GDD update and tuning pass** (`HpFactor`, attack numbers) after a 2–3 player playtest.

## 13. Open questions

- Should raids be gated by tower progress (for example floor 5 cleared) instead of onboarding step 2?
- Gold scaling: `floorScale` of the player's best floor means veterans get more Gold. Is that wanted, or should Gold be flat?
- Should a kill extend nothing (end at once) or give a 10 s victory lap? The current plan ends at once.

---

## Appendix: Blender assets

Generated by `tools/blender/generate_raid_assets.py`, which can be rerun headless:

```bash
"D:/SteamLibrary/steamapps/common/Blender/blender.exe" -b -P tools/blender/generate_raid_assets.py
```

The helpers live in `tools/blender/raid_kit.py`. Add `-- portal hollow_king` to rebuild only some of the assets.

- **Units and axes:** 1 Blender unit = 1 stud. Assets face +Y in Blender. They are exported with `axis_forward='-Z', axis_up='Y'`, `apply_unit_scale` and `bake_space_transform`, so they face −Z (the LookVector) in Roblox. A Roblox point is `(x, z, −y)` of the Blender point.
- **One FBX per asset**, holding one named mesh object per segment. Studio's 3D Importer brings it in as a Model of MeshParts that are already in position, and the code finds pieces by name.
  - `assets/models/raid/portal/RaidPortal.fbx` has four meshes: `RaidPortal_Frame` (palette-textured), plus `RaidPortal_Runes_Glow_Crimson`, `RaidPortal_Runes_Glow_Orange` (the brazier fire), `RaidPortal_Vortex` and `RaidPortal_Shards` (spun by the client about the pivot recorded in the JSON), which are all Neon.
  - `assets/models/raid/<boss>/<Boss>.fbx` has one mesh per rig segment (`HollowKing_Torso`, `HollowKing_UpperArmR`, …). Its glowing faces are split out as `<Boss>_<Segment>_Glow_<Colour>`, for Neon MeshParts welded to their segment.
- **Palette texture:** every non-glow face is UV-collapsed onto a swatch of `assets/models/raid/raid_palette.png`, a 256² image with 8×8 swatches, shared by all five assets. Each segment is therefore one MeshPart with one `TextureID`. Only append swatches to `raid_kit.PALETTE` and never reorder them, or every UV shifts.
- **Metadata:** `<Asset>.json` sits next to each FBX. For every segment it lists the name, the parent, the joint `Pivot` and the mesh bounding-box `Centre`/`Size` (all in Roblox studs from the ground centre), the triangle count, and each glow mesh with its colour. `RaidBossRigs` builds the `Motor6D`s from it: C0/C1 come from `Pivot` relative to each part's `Centre`, because the importer recentres every mesh on its bounding box.
- **Previews:** `assets/models/raid/previews/<asset>_{front,three_quarter,side,back}.jpg`.
- **Sources:** `assets-source/raid/<Asset>.blend`, one file per asset, regenerated by the script, so don't hand-edit them.
