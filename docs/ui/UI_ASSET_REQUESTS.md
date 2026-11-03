# UI Asset Requests

Art and audio the UI is wired for but doesn't have yet. Every slot is optional. Until a slot is filled, the code uses its drawn fallback (procedural frames, gradients, `GrimoireIcons`) or stays silent. To use an asset, upload it, then paste its `rbxassetid://` into `src/StarterPlayerScripts/UI/UIAssets.luau`. No other code change is needed unless a row says so.

Style: Gilded Grimoire. That means dark violet panels (`#0D0912`), gold rails (`#FACC15`), arcane violet accents (`#C084FC`), Cinzel for display text and Montserrat for UI text. Ink outlines should be thick and slightly hand-drawn. Never bake text into images, so localisation keeps working.

Priority: **P0** has the biggest effect on how fun the game feels. **P1** is strong polish. **P2** is nice to have.

## 1. Audio (`UIAssets.Sounds`)

Without audio, the UI feels flat. Every pull, click and reward should make a sound. All sounds play through `SoundService.SFX`, so the Settings SFX slider controls them. Use short, dry one-shots (no long reverb tails), mixed to peak around -6 dBFS.

| Slot | Pri | Brief |
| --- | --- | --- |
| `SummonCharge` | P0 | 0.6 s magical riser for the rift orb charging. Also played slower and lower as the 10x tease. |
| `SummonPulse` | P0 | Short bass thump with a shimmer. Plays 1–3 times as the orb pulses, at rising pitch. |
| `SummonBurstCommon` | P0 | Small pop and chime when a 1–3 tier card bursts. |
| `SummonBurstRare` | P0 | Bigger crystal burst for Superior+ and 4★ artifacts. |
| `SummonBurstJackpot` | P0 | Choir hit, gong and sparkle tail for Legendary+ and 5★ artifacts. It should feel like a jackpot. |
| `CardFlip` | P0 | Card whoosh and snap. |
| `StarTick` | P0 | Bright "ding". Plays once per star, pitched up each time. |
| `NewBadge` | P1 | Short "ta-da" stinger. |
| `ResultsPop` | P1 | Soft pop for each card landing in the 10x grid, pitched up each time. |
| `Click` | done | Uses the existing settings click (`139403951941162`). Replace it if a better sound is found. |
| `Hover` | P1 | Very quiet tick (played at 35% volume, throttled). |
| `Error` | P0 | Soft "denied" thud for not enough Gems or a refused action. |
| `ToastIn` | P1 | Notification chime. |
| `WindowOpen` | P1 | Page-turn or soft whoosh. |
| `TabSwitch` | P2 | Paper flick. It is in `UIAssets` but no screen plays it yet. To use it, set the attribute `FeelSound = "TabSwitch"` on the tab buttons. |
| `Reward` | P1 | Coins landing (offline rewards). |

Music, not wired yet: a **summon theme**, a 20–30 s loop that ducks the hub music while the reveal is open, and a **hub/Fortress ambient loop**. They would go in `SoundService.Music`, which the Settings Music slider already drives.

## 2. Summon reveal art (`UIAssets.Images`)

| Slot | Pri | Size | Brief |
| --- | --- | --- | --- |
| `RevealRays` | P0 | 1024² PNG | Sunburst of 12–16 soft rays. White on transparent, because the code tints it by rarity and spins it. It replaces the drawn bars. |
| `RevealGlow` | P0 | 512² PNG | Radial soft glow, white centre fading to transparent. Tinted at runtime. |
| `RevealSparkle` | P1 | 128² PNG | Four-point star sparkle, white. Used for every sparkle burst (reveal, rewards). |
| `RevealRiftOrb` | P1 | 512² PNG | Swirling rift or vortex, greyscale. Tinted and spun at runtime over the orb. |
| `CardBack` | P0 | 540×760 PNG | Back of a summon card, with a gold-framed grimoire sigil on deep violet. It shows for the first half of the flip. |
| `CardFoil` | P2 | 540×760 PNG | Holographic foil texture, greyscale. Not used yet. The current shimmer is a gradient sweep, and this would be overlaid on Superior+ cards. |

## 3. Hero cards and portraits

`HeroCard.Portrait` already uses `seed.Portrait` when a hero seed in `HeroCatalog` has one, and falls back to a 3D viewport of the rig otherwise. 2D portraits look better and cost much less than a `ViewportFrame` per card, which matters on the 10x results grid and the roster.

**P0: one bust illustration per hero.** Make them 512×512, transparent background, shoulders up, facing slightly left, with the weapon visible where it fits. Add a `Portrait = "rbxassetid://…"` field to each seed:

`hero_aaron`, `hero_archon`, `hero_astrea`, `hero_catio`, `hero_eolka`, `hero_han`, `hero_ignis`, `hero_jenna`, `hero_morrigan`, `hero_solaris`, `hero_valeria`, `hero_velkist`

**P1: full-body splash art per hero** at 1024×1536, for the single-pull reveal card and the Hero Index detail view. This needs a new `Splash` seed field and a small change to `SummonReveal.FillCard`.

**P1: rarity card frames.** One 9-slice frame per rarity band, 540×760, with a centre that can be sliced:
- Common/Uncommon: plain iron
- Rare/Superior: silver with a gem
- Epic/Legendary: gold with wings
- Mythical and up: animated-looking prismatic frame

These would replace the drawn `GildedGrimoire` card frame on reveal and roster cards. Wiring them in needs a small change to `MiniCard` and `FillCard`.

**P2: weapon art.** One icon per weapon type (`SWORD_SHIELD`, `DAGGERS`, `BOW`, `AXE`, `STAFF`, `TOME`) at 256², to replace the archetype-icon stand-in on artifact cards. Per-template weapon art would come later.

## 4. Banner key art

| Slot | Pri | Size | Brief |
| --- | --- | --- | --- |
| `BannerCallOfTheRift` | P0 | 1600×900 | Permanent banner. Swirling violet rift and floating tower silhouettes. Keep the left 40% calm, because the featured hero sits there. |
| `BannerStarsArrival` | P0 | 1600×900 | Limited banner. Gold starfall over the featured hero's biome. Needs a new version each time the limited hero rotates. |
| `BannerArtifactForge` | P1 | 1600×900 | Artifact banner. Molten forge, anvil and floating weapons. |

These need wiring. `FacilityController.BuildBannerView` and the Forge summon view still draw a gradient card, and they need an `ImageLabel` behind the featured portrait that reads these slots. It is about 10 lines each.

## 5. HUD and general

- **P1: currency icons** as images (Gold, Gems, Robux-styled premium) at 128². `GrimoireIcons` draws them well enough for now, but they are the most-looked-at icons in the game.
- **P1: facility building badges** at 256² for the Fortress Tree nodes and facility panels: Guard Post, Market, Training Grounds, Summoning Altar, Forge, Pit.
- **P2: biome emblems**, one per biome (10), for the tower selector and floor banners.
- **P2: rank frames** for the leaderboard top 3 (gold, silver and bronze laurels).

## 6. UI audit: what's done, what's still open

Done in this pass:
- Every button now has a hover/press spring, a click sound and a haptic, through `UIFeel` (global and opt-out). The rail buttons and other buttons that already animated themselves keep their own spring and gain sound and haptic.
- Windows pop in when they open (through `ModalFit`).
- Refusals give feedback. Before this, the Forge summon did nothing when you couldn't afford it.
- Toasts animate, and warnings shake.
- The offline reward counts up.
- The per-pull reveal has more stages: tease, flip, star pops, NEW badge, jackpot effects, fast-forward, gamepad support and AGAIN buttons. The Forge banner uses it too.
- The Settings SFX volume slider works now. `SoundService.SFX` was never created before.

Still open (recommendations):
1. **Close transitions.** Windows still vanish instantly.
2. **No dim behind the reveal.** This was a deliberate design choice ("No dim" in Phase 5). It is the one place a gacha game usually darkens the world, because a jackpot card over a bright sky loses punch. Consider a dim for the reveal only (about 0.5).
3. **Pity feedback.** The pity bar could pulse when 10 or fewer pulls remain, and flash gold when pity triggers.
4. **Currency change feedback.** The React HUD's Gold/Gems counters should count up or down and pop on change. `UIFeel.CountUp` and `UIFeel.Pop` are ready for this. It needs a hook in `HudApp`.
5. **Legacy screens still use the old Gotham fonts and emoji glyphs**, such as the Forge's `ICON_MAP` "⚔️" icons in the assign and upgrade views. Swap them for `GrimoireIcons`.
6. **Pixel-sized legacy windows**, such as the Blacksmith modal at 880×520 in `HUDController`, aren't fitted by `ModalFit`, so they overflow on phones.
7. **Gamepad.** Most windows don't set `GuiService.SelectedObject` when they open, so console players have to hunt for the cursor. The reveal does this now. Do the same in each controller's `Open`.
