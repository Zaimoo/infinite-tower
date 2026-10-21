# Current systems review — 2026-10-21

The tower rebuild has not advanced. This review changes no production code, Studio scripts, geometry, game settings, or publication state. Existing uncommitted Part 1 work is preserved. Fix the P1 findings before advancing the rebuild.

## Why Team Test failed to launch

The recorded launch failure is a Roblox API timeout. At **20:23:53 Asia/Manila**, Studio's request to `https://develop.roblox.com/v1/assets?assetIds=136256010643848` timed out. Studio immediately logged `Failed to start Team Test due to error checking place moderation status`. This is a failed status lookup; it does not establish that the place was moderated.

A subsequent attempt started at **20:25:24**, retried fetching the join configuration, accepted the server connection at **20:25:55**, and reached **TeamTestSuccess at 20:26:02**. It ended at **20:26:33** with a client-initiated stop, code 285, `lostConnection false`. An earlier 17:55 session also recorded DNS failures for the Team Test status API and `gamejoin.roblox.com`.

These logs support an intermittent service/network-resolution problem for the observed launch failure, rather than a Luau syntax or gameplay error. They do not identify whether the underlying network fault was local DNS, an ISP/router/VPN path, or Roblox infrastructure. A DNS probe from the restricted command environment returned access denied, so current host DNS health was not established. The initial MCP play-server endpoint error is also not proof of a broken game server: this was a cloud Team Test, and its client DataModel was successfully loaded with the correct player/place/job.

[Selected original log lines](team-test-evidence.txt) preserve the failed request and later successful connection. Connection success does not verify gameplay or multiplayer correctness. The separate `LightConfig` runtime failure below must also be addressed.

If the launch problem recurs, end the existing Team Test session and retry after connection health recovers; use local Server & Clients to test multiplayer independently of the cloud launch path. Roblox documents that only one collaborative Team Test session can run at a time in [Studio testing modes](https://create.roblox.com/docs/studio/testing-modes). No network settings or sessions were changed by this review.

## Findings, in repair priority

### 1. [P1] Jenna's model contains an obfuscated external module loader

**Studio only; present in the asset template and enabled Workspace preview.** [Captured LightConfig, line 40](<C:/Users/msi/Documents/ChatGPT/Infinite towers/tower-rebuild-baseline-20261021/studio-script-bodies/ReplicatedStorage.Assets.Heroes.hero_jenna.RightUpperArm.CrystalPauldron.LightConfig.luau:40>) fetches a Marketplace asset description. Its child [Type, line 130](<C:/Users/msi/Documents/ChatGPT/Infinite towers/tower-rebuild-baseline-20261021/studio-script-bodies/ReplicatedStorage.Assets.Heroes.hero_jenna.RightUpperArm.CrystalPauldron.LightConfig.Type.luau:130>) replaces each character with its decimal byte value; LightConfig stores the resulting number in `EasyConfiguration.Pose.Value` and [requires that number at line 86](<C:/Users/msi/Documents/ChatGPT/Infinite towers/tower-rebuild-baseline-20261021/studio-script-bodies/ReplicatedStorage.Assets.Heroes.hero_jenna.RightUpperArm.CrystalPauldron.LightConfig.luau:86>). Type's line 144 gates the load on `game.JobId ~= ""`, allowing different behavior in local Play and cloud Team Test/live servers. This is unrelated to the apparent lighting configuration purpose.

Fresh inspection confirmed both copies have `Disabled=false`, Legacy RunContext, and a child NumberPose `EasyConfiguration.Pose` with value `90983637061475`. Current LightConfig/Type hashes match the captured source. Studio Output contains an actual MarketplaceService HTTP NetFail at `Workspace.ModelViewer.JennaPreview.RightUpperArm.CrystalPauldron.LightConfig`, lines 40/72. That confirms the network lookup ran, not that the external payload ran. The remote module was not fetched, required, or executed during this review; its contents and prior execution remain unverified.

Quarantine the loader and children in **both** `ReplicatedStorage.Assets.Heroes.hero_jenna.RightUpperArm.CrystalPauldron` and `Workspace.ModelViewer.JennaPreview.RightUpperArm.CrystalPauldron`. Check generated copies too. `ArtPackVisuals.AttachAt` clones complete templates; removing only the preview leaves the template available for copying. Keep any required light behavior as locally reviewed code. This issue is separate from the proven moderation-status launch timeout.

### 2. [P1] Espionage completion requests award unlimited currency

**Repository and Studio.** [SyndicateService, line 41](C:/Projects/infinite-tower/src/ServerScriptService/ExtractionAndSocial/SyndicateService.server.luau:41) accepts completion codes without a server-owned interaction start, elapsed channel time, proximity, cooldown, or different-owner check. Missing/invalid targets fall back to the caller's own profile. Repeated blessings award Gems/Honor; self-leech then purge awards Gems/Gold.

An offline proof using each version's actual handler produced **+50 Gems/+10 Honor from two immediate blessings**, and **+100 Gems/+1,000 Gold from two immediate self-leech/purge pairs**. Enforce a validated server interaction and single-use completion, reject self/invalid targets, and rate-limit requests before payout. [Proof output](economy-review-proof-output.txt).

### 3. [P1] Studio profile synchronization redeploys deliberately benched heroes

**Studio only.** [Captured DataManager, line 383](<C:/Users/msi/Documents/ChatGPT/Infinite towers/tower-rebuild-baseline-20261021/studio-script-bodies/ServerScriptService.Core.DataManager.luau:383>) reapplies stale `DeployedSquadOrder` entries on every sync. The assignment handler sets `BENCHED` at line 819, but sync treats that hero as a legacy deployment and places it in the next free slot. Replacing a hero can similarly redeploy the displaced hero into another empty slot. The current SquadController still sends these bench/slot operations.

The extracted migration reproduced both behaviors offline. This breaks normal squad editing and prevents affected heroes from becoming eligible Pit donors. Run schema migration once, or restrict it to genuine legacy assignment states; reconcile deployment indexes only from the new authoritative assignments. [Proof output](economy-review-proof-output.txt).

### 4. [P1] A sixth player overwrites the first player's plot

**Repository and Studio.** [PlotManager, line 205](C:/Projects/infinite-tower/src/ServerScriptService/Core/PlotManager.server.luau:205) defaults to plot 1, scans five slots, then writes ownership even when no slot is free. Studio's current **MaxPlayers is 60**, with five islands. Player six therefore shares plot 1 with its original owner; either player's departure clears ownership and worker visuals for the other. Studio equivalent is captured PlotManager lines 176–183.

Handle exhaustion explicitly and align experience/server capacity with the five available plots. This is a multiplayer gameplay bug, not the observed cloud launch timeout. Static trace; six-client behavior was not played through.

### 5. [P1] Combat ticks erase equipped weapon ATK

**Repository and Studio.** Squad rebuild correctly passes the artifact to stat calculation at line 345. [CombatSimulation, line 1562](C:/Projects/infinite-tower/src/ServerScriptService/Combat/CombatSimulation.server.luau:1562) recalculates without that artifact and overwrites ATK every 0.2 seconds. `RefreshPlayerHeroStats` has the same omission at line 283. The stored artifact attack-speed interval survives, making weapons appear partially functional.

The actual formula bodies and extracted call sites reproduce **59 ATK after rebuild → 44 ATK after one tick**, losing the Common 1-star weapon's 15 ATK. All **112 star/rarity combinations** lose exactly their weapon contribution. Resolve the equipped artifact consistently in all stat paths. [Proof output](combat-proof.txt).

### 6. [P1] Enemy AoEs hit other existing tower floors and render warnings at the wrong height

**Repository and Studio.** [CombatSimulation, line 1392](C:/Projects/infinite-tower/src/ServerScriptService/Combat/CombatSimulation.server.luau:1392) and line 1473 use only X/Z distance for Nova/elite damage. The current 18-floor tower already stacks enemies and heroes vertically. The actual elite predicate accepts a hero **100 studs above** the enemy at the same X/Z. Telegraph messages omit Y; [EntityRenderer, line 424](C:/Projects/infinite-tower/src/StarterPlayerScripts/Rendering/EntityRenderer.client.luau:424) reconstructs a legacy arena height instead of the caster's floor.

Use the same floor/vertical context for activation, damage, carrier effects, and warning placement, and carry the authoritative context/height through the protocol. This is already a current bug, not merely an off-map rebuild prerequisite. [Predicate proof](combat-proof.txt); rendered appearance was not playtested.

### 7. [P1] Avatar resets retain cargo and can bypass extraction

**Repository and Studio.** Held cargo survives character death/removal because its player-keyed carrier table has no character lifecycle cleanup. [CombatSimulation, line 1818](C:/Projects/infinite-tower/src/ServerScriptService/Combat/CombatSimulation.server.luau:1818) banks that stale cargo using the replacement avatar's position, without requiring the held part to remain attached to that avatar. Reset while hauling and respawn at the plot: the new avatar reaches the safe banking radius without carrying the cargo back. Player removal at line 1775 also leaves the loot carrier entry uncleared.

[RelicService, line 393](C:/Projects/infinite-tower/src/ServerScriptService/ExtractionAndSocial/RelicService.server.luau:393) has the same avatar-reset mismatch between `CarrierToRelic` and the current avatar used for pad detection. Drop/clear carrier state on character removal/death, and validate the current attachment/context before payout. Static lifecycle finding; reproduce reset/death/disconnect in an isolated Studio test after removing the external loader.

### 8. [P2] A rejected assignment still removes the existing facility worker

**Repository and Studio.** [DataManager, line 783](C:/Projects/infinite-tower/src/ServerScriptService/Core/DataManager.server.luau:783) removes a hero from facility indexes before validating the destination. Request `SQUAD_AUTO` for an infirmary worker with all squad slots full: the request fails, the hero still says `FACILITY_INFIRMARY`, but its worker UUID has disappeared from the facility. Source also has the full-conduit case.

The actual repository assignment block reproduced this inconsistency offline. Validate all destination/capacity conditions first, then commit assignment and redundant indexes together. [Proof output](economy-review-proof-output.txt).

### 9. [P2] Retaliation can continue into safe plots or beyond its authorization window

**Repository and Studio.** [CombatSimulation, line 1155](C:/Projects/infinite-tower/src/ServerScriptService/Combat/CombatSimulation.server.luau:1155) checks the attacker at command time, while target selection at line 1508 and damage at line 1665 do not revalidate both players' safety or grudge expiry. A retreating target can remain attackable in a safe plot. `IsLootThief` is set at line 843 and has no expiry/clear during the avatar's lifetime, bypassing the intended bounded retaliation window.

Revalidate the server authorization and both contexts at acquisition and impact; expire the theft state consistently. Static finding; focused two-player retreat/expiry reproduction remains required.

### 10. [P2] Routine profile updates reset synthesis's rare-donor confirmation

**Repository and Studio.** [HUDController, line 1570](C:/Projects/infinite-tower/src/StarterPlayerScripts/UI/HUDController.client.luau:1570) refreshes synthesis on every profile packet. [SynthesisController, line 280](C:/Projects/infinite-tower/src/StarterPlayerScripts/UI/SynthesisController.luau:280) queues another preview, and line 287 clears `ArmedRare`. WaitingRoomService syncs every three seconds, or every second while infirmary recovery changes stamina. A player reading the warning can repeatedly lose confirmation; refresh also lacks a busy guard.

Only request a new preview when relevant inputs change, preserve confirmation for unchanged valid inputs, and guard a commit in flight. Ordinary stamina regeneration is deliberately excluded from Pit fingerprints except for exhaustion changes; it is not itself a server-token bug. Static UI-flow finding.

### 11. [P2] Late startup misses initialization for an existing character

**Repository and Studio.** [DataManager, line 897](C:/Projects/infinite-tower/src/ServerScriptService/Core/DataManager.server.luau:897) subscribes only to future `CharacterAdded` events. If dependencies finish after an avatar exists, that avatar misses initial Honor/IsRogue attributes and collision-group setup until respawn. Run a shared initializer for `player.Character` immediately as well as for future characters. Static timing finding; delayed startup was not simulated.

## Verification and source/Studio differences

- Reviewed repository `C:\Projects\infinite-tower`, branch `codex/tower-rebuild-part-1`, HEAD `b2a9ef76c0a54cd23d6a5684193a4bca6fa50f25`, plus the connected place `136256010643848` / universe `10771894864`.
- Re-read the current Studio inventory. The 54-script application scope still has 16 differing shared scripts and six Studio-only scripts versus the prior source baseline. Of those 54, 53 match the earlier Studio capture; only Studio-only SquadController changed. Its current source was exported as [Studio.SquadController.luau](Studio.SquadController.luau) and reviewed for its assignment calls. The full [fresh inventory](studio-inventory.json) includes 65 scripts, adding stored backups and the Workspace model preview. No bulk synchronization was attempted.
- Fresh inspection: `MaxPlayers=60`, `StreamingEnabled=true`; both LightConfig copies enabled. The previous source export was used only after fresh hashes confirmed the reviewed bodies match.
- Existing check: `tests/run.ps1 -LuauDirectory 'C:\Users\msi\AppData\Local\Temp\infinite-tower-luau-0.743'` exited 0. Production compilation passed; **52 Pit and nine tower foundation checks passed**. These are repository/module checks, not coverage of live handlers, the full simulation, UI, or Studio-only code.
- Compiled all **48 distinct current Studio application source bodies** with the same CLI, without executing them: exit 0. Used hash-matched captured bodies plus the freshly exported SquadController. [Compiler evidence](studio-compile.txt). This checks syntax, not Roblox runtime behavior or trustworthiness.
- Seven isolated economy/migration/assignment bug reproductions passed. [Generator](generate-economy-review-proof.ps1), [generated proof](economy-review-proof.luau), [output](economy-review-proof-output.txt).
- Combat proof passed for 112 equipment cases and a vertically separated elite target. [Generator](combat-proof.ps1), [output](combat-proof.txt). These execute extracted production statements with offline stubs, not complete game services.
- `git diff --check` passed. The tracked changes in tests/run.ps1 and tests/roblox-module-shim.luau predate this review and were not modified here.
- No fresh end-to-end multiplayer/reset/retaliation/mobile acceptance test was completed. No external payload execution or Studio production mutation was performed.

## Rebuild prerequisites and next work

Quarantine the embedded loader first, then repair reward validation, squad assignment/migration, plot capacity, combat stats/context, and carrier lifecycle. Add focused regressions that fail on these defects, and verify the fixes with two clients plus capacity/reset cases. Reconcile only the intended source/Studio changes before advancing Part 2.

The saved Studio place remains a required dependency: the Rojo mapping alone does not supply its binary hero/mob models, remotes, or plot instances. Missing initial profile packets are not a permanent bootstrap failure here, because WaitingRoomService resends full profiles. Preserve the place and its existing untracked assets; do not treat a passing source compile or a fresh source-only build as equivalent to this live implementation.

The previously documented future-room blockers still apply: room-local packet coordinates, explicit safe zones instead of world radius, floor-scoped relevance, and the global 255-entity truncation. They have not been implemented in this review.
