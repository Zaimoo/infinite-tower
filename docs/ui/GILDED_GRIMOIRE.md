# Gilded Grimoire: UI Theme

**Gilded Grimoire** is the Infinite Tower UI theme. It takes the game's gothic palette (obsidian, amethyst, antique gold) and draws it in a chunky cartoon style. To redesign a screen, ask for it "in Gilded Grimoire".

The source of truth is `src/ReplicatedStorage/Shared/Util/GildedGrimoire.luau`.

## The look

| Element | Rule |
| :--- | :--- |
| **Panels and buttons** | Top-lit gradient fill, a thick black **ink** outline (2–3.5 px) and a thin inset **gold rail** (1.4 px, 3 px in from the edge). Rounded corners: windows 16 px, panels and cards 12 px, rows, slots and buttons 10 px. |
| **Tones** | **Violet** is the default panel. **Deep** is used for nested panels and **Slate** for locked items. **Bronze** marks Gold, **Teal** marks Gems, **Crimson** marks power or danger, and **Gold** is the primary action, and **Action** (bright amethyst) is the default for confirm and initiate buttons. |
| **Fills on text objects** | A UIGradient on a TextButton or TextLabel also tints its text. Give text objects a solid tone with a light white-to-grey shading gradient (`fillTone` in `GothicBoxStyle`), or put the text in a child label. |
| **Titles, labels, buttons** | Cinzel Decorative Heavy, white fading to antique gold, with a black ink outline. Large screen titles are letter-spaced (`S Y N T H E S I S`). |
| **Numbers** | Cinzel Heavy with an ink outline. Changes show as green or red floaters. |
| **Body text** | Cinzel Bold in parchment white, with a light ink text stroke. |
| **Icons** | Drawn from shapes in `Shared/Util/GrimoireIcons.luau` (archetypes, currencies, facilities, branches, lock, spark). Each shape has a gradient, a 2–2.6 px ink outline and a white sheen. An icon may break out over its card's edge. **No emoji** anywhere in the UI; weapons will get their own art from their models. |
| **Summon buttons** | `Shared/Util/GrimoireSummonButton.luau`: Action-tone button, heavy title over a drawn Gems icon and the cost. Hero banners and the Forge share it. |
| **Bars** | Pill-shaped, ink-outlined, with a gradient fill and a top shine. A full gauge glows gold. |
| **Gothic accents** | Gold, ink-outlined diamond studs on window and card corners. |
| **Motion** | Hover grows a button about 10% or brightens its rail. Building a node or unlocking something plays a short pop. |

## How to use it

- **React screens:** use `UI/Hud/Components` (`Panel`, `HeavyLabel`, `Body`, `IconAt`) and `UI/Hud/Gothic` (`Box`, `Label`).
- **Imperative screens:** `GothicBoxStyle.Apply` and `GothicFont.Apply` already render in this theme. `GildedGrimoire.Frame(frame, { Class, Tone })` frames any object. `GildedGrimoire.Watch(root)` converts a screen's leftover Gotham text, and anything added to it later.
- **Icons:** imperative screens call `GrimoireIcons.Create(name, size, parent)` or `GrimoireIcons.IconText(name, size, parent)` for an icon beside a number; React screens use `Hud/Icons` (`Icon`) or `Components.IconAt`. Add new drawings to `GrimoireIcons.Drawings` in the same style.
- **Fonts:** never use Gotham in a new screen. Use `GildedGrimoire.Fonts.Title`, `.Number` or `.Body`.

## The UI kit (`UI/Kit`, "Brighter Grimoire")

New and reworked screens build from the shared kit (`docs/ui/UI_OVERHAUL_PLAN.md` §3–§4) instead of drawing their own buttons, bars and popups. `require(UI.Kit)` gives:

| Piece | What it is |
| :--- | :--- |
| `Tokens` | Brighter Grimoire colours: lifted `Surface` tones; saturated `Domain` header colours (Forge, Pit, Tower, Fortress, Index, Store, Settings, Backpack, Squad); `Intent` button colours; `Severity` colours and icons; the type scale (13 px minimum); spacing; radii. `Tokens.Paint(frame, tone)` draws fill, ink and rail. |
| `Button` | One button. `Intent` sets the colour: **Primary** (gold, the window's main action), **Confirm** (jade), **Travel** (azure), **Secondary** (violet), **Danger** (crimson). Disabled is slate with a lock and always has a `Reason`, shown on hover and after a tap. |
| `Bar` | Pill bar with its numbers inside, a ghost `Preview` fill and a gold glow when full. |
| `DeltaStat` | Before → after row with a green or red signed change. |
| `CurrencyChip` | Icon and number pill. Changes count up with a floater; `Need` turns it red when unaffordable. |
| `Callout` | A warning next to the action (`info`, `warn` with a pulse, `block`), with an optional fix-it link. It replaces footer status text. |
| `Tooltip` | One tooltip layer: hover (0.35 s), long-press (0.4 s) or gamepad focus (0.5 s). It flips at screen edges. `Tooltip.Bind(gui, fn)` and `Tooltip.Flash(gui, reason)`. |
| `Notify` | Up to 3 stacked toasts, top centre. Repeats coalesce ("×3", or amounts add up). Server `SystemToast` messages use it. |
| `Confirm` | Confirmation dialog in three tiers: Soft (optional "Don't ask again this session"), Hard (lists what is lost, arms after 1 s) and Critical (hold 1.2 s). `Kit.Rules.ConfirmTier(action, ctx)` picks the tier from the plan's risk table. |
| `Motion` | `Open`/`Close`, `TabSwap`, `Stagger`, `Select`, `Attention`, `NumberTick`, `BarFill` and `Success`. All respect Reduce Motion. |
| `React` | React wrappers for `Button`, `Bar`, `DeltaStat`, `CurrencyChip` and `Callout`. |

Building blocks return a handle with `Instance`, `Update(props)` and `Destroy()`. Imperative screens call `Kit.Button.Create(parent, props)`; React screens use `e(Kit.React.Button, props)`. The pure rules live in `Shared/Util/UiKitRules` and are covered by `tests/ui-kit.spec.luau`. `tests/studio-ui-kit-client.luau` builds a showcase of every piece in a Studio playtest.

`Tokens.Paint` adds the rail as a child frame. Never put a `UIListLayout` or `UIGridLayout` directly in a painted frame: lay its contents out in a child frame instead, or the rail gets laid out as an item.

## Where it's used

- The HUD rails and the expanded Squad Status tiles. The Next Goal card, Gold/Gems bar, Squad Power badge and the Squad drawer strip now use **Clear Glass** (`Theme.Glass` in `UI/Hud/Theme.luau`; see `PHASE_5_REACT_UI_AND_MENUS.md` §2.0b).
- The Pit tabs, the facility panel and the Hero Index.
- The Settings screen (gear on the Left Rail): panels, tabs, sliders, toggles and buttons. Its accent setting defaults to antique gold.
- In the tower: the Tower selector (floor tiles, biome cards, details panel, actions) and hero and monster nameplates with pill HP and skill gauges (`GildedGrimoire.Bar`). The boss and floor-progress banner, alert banners (toasts, loot stolen, squad down, squad compromised, the squad-vitality tooltip), the carried-loot pill, the duel banner and the offline-reward popup now use **Clear Glass** (below).
- Through the reskinned gothic kit: Summoning, Synthesis, Promotion, the Forge, and every other screen built with `GothicBoxStyle` or `GothicFont`.

## Clear Glass (HUD zones)

The HUD's on-screen zones use a lighter style, **Clear Glass**, instead of the chunky framing above. Its tokens live once in `GildedGrimoire.Glass` (the React HUD reads them as `Hud/Theme.Glass`):

| Token | Value | Use |
| :--- | :--- | :--- |
| `Base` | `#0D0912` at 0.35 transparency | Panel body |
| `BaseRaised` | `#261C32` at 0.25 | Header strips, tiles |
| `Hairline` | `#F6F4FF` at 0.82 | The single 1px stroke on every panel |
| `Text` / muted | `#F6F4FF`, muted at 0.15 | Text (kept near-opaque for 4.5:1 over a bright sky) |
| `Arcane` | `#C084FC` | Active / focused; the floor kill bar |
| `Royal` | `#FACC15` | Currency, primary action, the local player, a full kill bar |
| `Danger` | `#EF4444` | Down, badges, boss HP, loot stolen |
| `Vital` | `#4ADE80` | HP, positive deltas |

- **Panels:** 6 px corners, one hairline stroke, no gradients or ink. A 2px accent bar down the left edge carries the meaning colour on alert banners.
- **Type:** Montserrat SemiBold for labels, Montserrat Bold for numbers and headlines, Cinzel Bold only for hero names and the Squad Power number.
- **Where:** the Next Goal card, Gold/Gems chips, Squad Power badge, the Squad drawer strip, the leaderboard, and the imperative banners and popups listed above. The HUD rails and the expanded Squad Status tiles stay in Gilded Grimoire.
- **Imperative code:** `GildedGrimoire.Reframe(frame, { Tone = "Glass", Rail = accent })` or `GildedGrimoire.GlassFrame(frame, opts)` for panels, `GlassText` / `GlassTexts` for labels, `GlassBar` to flatten a `GildedGrimoire.Bar`. React code uses `Hud/Components` (`Glass`, `GlassText`, `SectionLabel`, `Brackets`).
