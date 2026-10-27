# Infinite Tower: Become a Master!

A Roblox squad-command action RPG with extraction and fortress progression, inspired by *Pick Me Up, Infinite Gacha*. The player is a **Master** who commands a squad of up to 5 gacha heroes. Squads climb a 50-floor Infinite Tower split into 10 biomes, with a Biome Boss every 5 floors. Between runs, the player develops a private Fortress Plot. Each server holds 6 players, one plot each.

`docs/GAME_DESIGN.MD` is the source of truth for design. Read the relevant section before changing a system, and update it in the same change when behaviour changes.

## Roblox skills

Also follow `AGENTS.md`. Before working on a topic, use the matching `roblox-*` skill, such as `roblox-luau`, `roblox-networking`, `roblox-security` or `roblox-data-stores`.

## Layout (Rojo, `default.project.json`)

- `src/ReplicatedStorage/Shared/Config/`: authoritative data tables, including `HeroCatalog`, `ArtifactCatalog`, `ArchetypeCombatSkills`, `StatBalance`, `FacilityConfig`, `TowerFloorConfig` and `MobCatalog`.
- `src/ReplicatedStorage/Shared/Util/`: shared logic, including `StatFormulas`, `WeaponPromotion`, `TowerProtocol` and `AttackTimeline`.
- `src/ReplicatedStorage/Assets/`: procedural builders (`WeaponModelBuilder`, `TowerEnemyRigs`), and `ArtPackVisuals` (template attachment and a generic animator for non-hero rigs).
- `src/ReplicatedStorage/Assets/HeroRig/`: code-authored hero rigs. The pieces are `HeroRigSpec` (skeleton, sockets, axis convention), `HeroCostumes` (every hero's look as data), `HeroRegistry` (builds the templates), `HeroSockets` and `HeroLoadout` (weapons), and `HeroClips` and `HeroAnimator` (client animation). Contract and history: `docs/hero-rig-rebuild-plan.md`.
- `src/ServerScriptService/Core/`: `DataManager` (profiles, artifacts, equip/craft/summon remotes, save migration), plus tower floors, traversal, the Pit and offline rewards.
- `src/ServerScriptService/Combat/`: `CombatSimulation` (the 5 Hz server-authoritative sim) and `TowerEncounterRuntime`.
- `src/StarterPlayerScripts/`: `UI` (Forge, HUD, Squad, Facility and Tower controllers), `Rendering` (`EntityRenderer`, which interpolates at 60 FPS) and `Input`.
- `tests/`: `*.spec.luau` suites and the `studio-*` playtest scripts.

## Architecture rules

- The server is authoritative. Clients only render and send requests, and the server validates every remote argument.
- Networking uses binary buffers: 14-byte records in the Central Hub, and the room-local v2 protocol in the tower (46-byte header, 24 bytes per entity, at most 32 records per batch). See GDD §8.
- New config modules use `--!strict` Luau. Match the surrounding style: config files use tabs, and some util modules use dense one-line style.
- `DataManager.SyncProfile` runs lazy migrations on saved profiles. Any change to the save schema needs a migration there. Never assume old profiles match the new shape.

## Core design facts

- **Heroes** have combat stats plus a labor output used by facilities. Hero banners: *Call of the Rift* (permanent, 1★–5★) and *A Star's Arrival* (limited, 1★–7★). Both cost 100 Gems for one pull or 900 for ten. The level cap is 50.
- **Archetypes** set role, base stats, attack interval, range, labor and weapon type. Each hero has its own Basic/Special/Skill kit (`ArchetypeCombatSkills`, keyed by hero, falling back to archetype). Basic and Special attacks charge a 0–100 skill gauge.
- **Artifacts are weapons.** Each hero equips one, and each archetype allows exactly one weapon type:

  | Archetype | Weapon |
  | --- | --- |
  | Vanguard | `SWORD_SHIELD` |
  | Striker | `DAGGERS` |
  | Marksman | `BOW` |
  | Miner | `AXE` |
  | Scholar (mage) | `STAFF` |
  | Healer | `TOME` |

  There are no rings and no separate shields.
- **Artifact rarity** is inherent (16 tiers, Common to Origin) and never upgrades. Star promotion (1★–7★, multipliers 1.0 to 16.0×) is the only upgrade, and it consumes donors of the same template. Formula: `WeaponDamageMultiplier = 1 + Power/40`. The artifact banner costs 160 Gems for one pull or 1,600 for ten. It has a 50-pull pity and guarantees at least one Rare in every ten-pull.
- **Fortress facilities:** support facilities are unlocked and levelled in the Fortress Tree (which also opens squad slots 2–5). There is no Infirmary; benched heroes recover stamina passively. The Guard Post makes AFK/offline Gold, the Market multiplies tower loot, and the Training Grounds multiply squad combat power.
- **Contested loot:** loot drops physically and has to be carried and banked. Stealing it triggers a 3-minute retaliation window for PvP at 25% damage. Defeated heroes enter `COMA`.

## Testing

```bash
pwsh tests/run.ps1
```

This compiles every `src` script with the official Luau CLI, then runs the spec suites (pit, forge, combat-skills, tower*). If the CLI is missing, add `-InstallLuau`. Visual and multiplayer behaviour needs a Studio playtest. The `tests/studio-*` scripts help, and Studio MCP can drive Studio when it is connected.

## Git

- Branch off `main` and merge through pull requests.
- Use conventional commits, such as `feat(scope): ...`, `fix(...)` and `docs: ...`.
