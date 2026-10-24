# Separate sprint: enemy art, animation, and presentation polish

Status: **IMPLEMENTED (CLI VERIFIED; Studio playtest NOT VERIFIED — Place not open in Studio).**

Retains Part 3's authoritative attack definitions and original synchronized start times. Cosmetic clips, effects, and markers never become damage or reward authority.

## Completed work

- Expanded `src/ReplicatedStorage/Assets/TowerEnemyRigs.luau` with 10 distinct biome material/color/lighting palettes and family-specific articulated Motor6D builders covering arthropods (`CRAWLER`, `INSECT`, `CRUSTACEAN`, `SCORPION`), `QUADRUPED`, `AVIAN` / `GIANT_AVIAN`, `SERPENT`, and all `BIPED` / `TREANT` / `COLOSSUS` variants across all 40 enemies.
- Upgraded `src/ReplicatedStorage/Assets/TowerEnemyClips.luau` with `plantedPose` leg counter-rotation (`LegL`, `LegR`, `KneeL`, `KneeR` compensating against torso pitch/yaw and vertical drop) so feet stay planted during windups, cleaves, projectile casts, slams, and sweeps, plus dedicated locomotion and attack clips for crawlers, quadrupeds, avians, serpents, casters, elites, and bosses.
- Upgraded `src/ReplicatedStorage/Assets/EnemyAnimationController.luau` and `src/ReplicatedStorage/Shared/Util/AttackTimeline.luau` to support `PROJECTILE` attacks (ground corridor telegraph + charging/flying orb + impact burst) and inner progress-fill discs on `SELF_DISC` / `TARGET_DISC` warnings within `MAX_EFFECTS = 12`.
- Retained editable native model/clip sources (`TowerEnemyRigs.luau`, `TowerEnemyClips.luau`) with `AssetId = nil` and `AnimationId = nil` (`LOCAL_AUTHORED_UNVERIFIED`).
