# Phase 1: connector geometry

Status: source implemented; CLI checks and Rojo build pass. Studio join/clearance sweeps are pending because MCP reports no open place. This is not gameplay certification.

- Added connector IDs, direction, usable width, and shared landing footprints.
- Flat landings are eight studs wider than their ramp. Inclined decks stop outside the upper terrace's full shoulder footprint, avoiding the former upper-edge step. Lower endpoints extend inward on short links to preserve the 15-degree maximum.
- Builder uses exact top planes, flush stair tops, and two-stud curb setbacks. Scenery clearance includes the actual landings, diagonal shoulders, and crossing terrace edge trim.
- Basin returns now meet the actual chasm floor (`Bottom - 4`), with a longer run and two landings.
- CLI regressions cover upper-slab separation, full-width landing overlap, layout connectivity, maximum slopes, return heights, patrol routes, and existing gameplay contracts.

Validation performed: `pwsh tests/run.ps1`; official Luau compilation of `tests/studio-tower-joins.luau`; `rojo build -o build.rbxl`; `git diff --check`.

Next validation: after opening Infinite Towers and connecting Rojo, run `tests/studio-tower-joins.luau` in Edit mode for floors 1-50. It refuses to replace existing rooms, builds/destroys one temporary room at a time, and sweeps center/shoulders and diagonal pad approaches both ways. Then check player Humanoid traversal and the existing navigation probes. Do not mark Phase 1 accepted until those checks pass.
