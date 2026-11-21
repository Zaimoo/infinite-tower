---
name: biome-floor-redesign
description: >-
  Redesign a biome's five tower floors one at a time as hand-authored floors: a plan prompt with
  the biome's story, then per floor a guide image from the user, an AUTHORED layout, sculpted
  terrain, a Blender prop kit, the floor's set pieces and ecosystem, a lighting grade, tests and
  docs, verified in Studio and shipped as its own PR into main. Use when the user asks to
  redesign, relayout or "do the same" for a biome's floors (Verdant 1-5, Fungal 6-10, Ashen
  11-15, Frozen 16-20, and on), to plan a biome's floor layouts, or says one floor "looks too
  similar" to another, "looks unnatural", "is too blocky" or "floats".
---

# Biome floor redesign

Each biome has five floors (biome N is floors 5N-4 to 5N; the fifth floor is the Biome Boss
arena). This skill takes one biome from the generic seeded layouts to five hand-authored floors.
The design lives in a plan prompt (`docs/prompts/<biome>-floor-layouts-prompt.md`). This skill is
the procedure. The Studio checks are in `references/studio-verify.luau`.

**Guide images gate every floor.** Never start building a floor without asking the user for its
guide image (step 2). The image sets the floor's mood, shapes and landmarks. Use it as
inspiration, never a 1:1 copy, and keep the plan's layout rules.

## 0. Set up

1. Read `CLAUDE.md`, `AGENTS.md`, `docs/GAME_DESIGN.MD` §3.3, `docs/TOWER_NAVIGATION.md` and the
   biome's section of `reference/infinite_towers_biomes.md`. Use the `roblox-world-building`,
   `roblox-luau` and `roblox-studio-mcp` skills.
2. Read one finished biome's plan prompt and its floors in code as the model, for example
   `docs/prompts/fungal-hollow-floor-layouts-prompt.md` with `AUTHORED[6..10]`.
3. `git fetch origin`, then branch the floor from `origin/main` (`feat/<biome>-floor-<N>`). Work in
   the main folder: Rojo syncs from there.
4. Make a task list with one step per phase below.
5. Files with CRLF endings (`git ls-files --eol <file>`): keep the endings in scripted edits.

## 1. Plan the biome (once per biome, then stop)

Write `docs/prompts/<biome>-floor-layouts-prompt.md`, modelled on the earlier biomes' prompts:
- **Role:** two specialists, a level designer (topography, sightlines, combat space) and an
  environment artist (ecosystem, materials, light).
- **Ecosystem and story:** the scene; the lost builders and their motif; a thread the player
  follows across the five floors that builds to the boss; each floor's story beat. Every prop must
  trace back to it.
- **Per floor:** a one-line shape idea, an ASCII map, a terrace table (`Id`, name, X/Y/Z, size,
  terrain or deck), the links (`Paths`, `Stairs`), camps and patrols, terrain (pools, islands,
  shapes, decks, bridges), numbered set pieces, the kit it needs, and a lighting grade.
- **Contrast:** each floor must read differently from its neighbours. Vary where the Apex sits
  (behind, hidden, in the middle, raised), how you reach it, the dominant landform, and the
  light. "Floor 10 looks too similar to floor 9" is the failure this prevents.
- **Tests and checks:** what each floor's spec test asserts and what to look at in Studio.

Stop after the plan and ask the user to review it. Do not start a floor in the same turn unless
they said to.

## 2. Ask for the floor's guide image (before every floor)

Before any code for floor N, ask the user, with AskUserQuestion if available:
"Do you have a guide image for Floor N (<name>)? Attach it, or say to go ahead from the plan."
Wait for the answer.
- **With an image:** save it as `reference/<Biome> <N>.<ext>`. Write down what you take from it
  (landforms, landmarks, palette, mood) and what you leave out. Update the floor's section in the
  plan prompt before building, and keep the plan's runtime rules (camps, clearance, links).
- **Without one:** build from the plan, and say so in the PR.

Ask again for each floor. One floor's image never carries over to the next.

## 3. Lay out the floor (`TowerLayout` `AUTHORED[N]`)

1. **Choose the authored-terrain system.** Two exist. Fungal floors use `Terrain = {Direct,
   Surface, Decks, DeckThickness, Shapes, Pools, Islands, Bridges, NoApexShelf, LiquidRise,
   FloorDip, GroveScale, GroundCover}`, `Skylight` and `Portals`. Verdant, Ashen and Frozen floors
   use top-level `DirectTerrain`, `Decks`, `Suspended`, `Masonry`, `Liquid`, `TerrainFeatures`,
   `Patrols` and `ReplacePatrols`, plus the masonry and path style tables in
   `TowerRoomBuilder`. Read the latest `AUTHORED` entries and use the system closest to the floor,
   rather than adding a third.
2. **Write the entry:** `Key = "<biome>:<n>"`, `Name`, `PathStyle`, the terraces, `Paths`,
   `Stairs`, `Names`. Keep every terrace id and role the runtime expects (Sanctuary, Basin, both
   Galleries, Crossing, Apex, and both Bastions from index 4).
3. **Rules that bit before:**
   - Terrain terraces sit on 4-stud planes (`Y % 4 == 0`). Decks and ramps can be at any height.
   - Ramps stay at or under 15 degrees. `TowerLayout.Validate` must find nothing the canonical
     layout doesn't.
   - A Round shape's rock apron reaches about 30-36 studs past the shape, so a pool or moat round
     it must be bigger than it looks on the map.
   - Portal spots, camps and patrols come from the layout. Check `Layout.PortalSpots(index, N)` and
     `Layout.PatrolRoutes(index, N)` after any change.

## 4. Build the floor's kit in Blender (only what the floor needs)

1. Check the existing kits first (`assets-source/tower/*/manifest.json`, `TowerBiomeKit`) and
   reuse what fits.
2. Write `tools/blender/generate_<biome>_f<N>_kit.py` (copy the layout of an existing generator)
   and export to `assets-source/tower/<biome>_f<N>_kit/` (FBX, .blend, `manifest.json`, previews).
   Commit the generator: `fungal_f10_kit` shipped without one and can't be rebuilt.
3. Register each template in `TowerBiomeKit.ExtraTemplates` (Size, Min, Roles from the manifest)
   and add the kit to the kit comment list. Template names must be unique across all kits. Add
   big pieces to `CastsShadow`, and new colour roles to the role type and the biome palette.
4. Every template needs a part-built fallback in `TowerBiomeAssets` until it is imported.
5. **Uploading a kit creates permanent Roblox assets: ask the user first.** On a yes: upload the
   FBX, insert it, run `tests/studio-tower-biome-kit-import.luau`, and ask the user to save.

## 5. Dress the floor (`TowerBiomeAssets`, lighting)

1. Put the floor's set pieces in its own block (Fungal: `if fungalFloor == N then ... end`), and
   use the shared helpers (`piece`, `group`, `kitAt`, `onTerrain`, `groundY`).
2. **Clearance removes a whole prop group if any one part fails, without warning.** After every
   build, count the floor's set pieces (`references/studio-verify.luau`). The cleanup tests are:
   - `CampHitTest`: any part whose centre is within 34 studs of a camp centre, or whose box comes
     within 7 studs of a mob slot (camp centre plus (0,0), (±18,+12), (±12,-16)), inside the band
     2 studs below to 22 above the camp. Large kit meshes have large boxes: a mushroom's gill and
     tendril mesh reached a boss slot from 37 studs away.
   - `WalkwayHitTest`: the lane boxes along every link and landing, tilted with the slope.
   Fix a removed piece by moving or turning it. Never raise it out of the way on a plinth.
3. **Natural, not stacked.** Landmarks grow from the ground (`groundY`), with roots, rock and moss
   at the foot. Never stand a tree or mushroom on a block, pillar or shelf. Avoid square
   platforms that read as blocky: use `Shapes` (round) terraces and noise-warped aprons.
4. Positions in the floor block are room-local. When you set `.CFrame` yourself, add `origin`.
5. Keep at most 24 lights per floor. Count them after every build.
6. Add `HubLighting.FloorGrades[N]`, a grade unlike the neighbouring floors'.

## 6. Tests and docs

- `tests/tower-layout-variants.spec.luau`: a "Floor N is the hand-authored ..." test (links and
  kinds, the camp count, the defining layout rule) and, for terrain floors, a "Floor N's terrain
  is the walking surface" test.
- `tests/tower-biome-kit.spec.luau`: the new templates exist, stand on their origin and use known
  roles, and a `FloorGrades[N]` assert.
- `docs/GAME_DESIGN.MD` (the floor's bullet under hand-authored floors), the plan prompt (status
  and anything changed in the build), and `docs/TOWER_NAVIGATION.md` if navigation rules changed.
- Run `pwsh tests/run.ps1`. If the Luau CLI is missing, ask before downloading it.

## 7. Verify in Studio

Use `references/studio-verify.luau` (probe, build, then the spawn, route, portal and set-piece
checks).
1. **Probe:** clone `ServerScriptService.Core` into `ServerStorage._CoreProbe` and the three
   tower configs into `_FreshConfig`, patch the requires, and build with
   `Builder.Build(N, 4)`.
2. **Pass bar:** no new `Validate` problems, every spawn and portal grounded, every link walkable
   both ways, every set piece present, 24 lights or fewer.
3. **Screenshots:** from the arrival, from the Apex and of each landmark. Compare them with the
   guide image and with the neighbouring floors, and show the user.
4. **Clean up:** clear the probe terrain, `workspace.TowerRooms` and both probe folders. Never
   leave preview lighting on the Edit place, and never use `ChangeHistoryService:Undo` to revert
   (it undid an unrelated edit once). Ask before stopping a playtest.

## 8. Ship each floor on its own

1. `git fetch origin` and merge `origin/main` before the PR. These files conflict often: merge
   with `git merge-file --diff3 --diff-algorithm=histogram`. Then check every junction where two
   floors' tables meet for a missing `},` or `end)`, and rebuild in Studio. Main often moves while
   you work.
2. Commit as `feat(tower): author <Biome> floor N (<Name>)`, with no Claude attribution lines.
3. Open one PR per floor into `main`. **Do not stack PRs:** this repo keeps head branches after a
   merge, so a stacked PR merges into its parent branch and never reaches `main`. Start the next
   floor from `origin/main` once this one merges. If it must build on an unmerged floor, tell the
   user to change its base to `main` before merging.
4. If `gh` is missing, open the PR in the browser pane (the user signs in themselves).
5. Report what was verified, what wasn't (tests not run, kit not uploaded), and the PR link. Then
   go back to step 2 for the next floor.
