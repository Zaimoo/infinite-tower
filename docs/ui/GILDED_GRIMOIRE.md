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

## Where it's used

- The HUD rails, Next Goal card, Squad Status Card, Gold/Gems bar and Squad Power badge.
- The Pit tabs, the facility panel and the Hero Index.
- The Settings screen (gear on the Left Rail): panels, tabs, sliders, toggles and buttons. Its accent setting defaults to antique gold.
- In the tower: the Tower selector (floor tiles, biome cards, details panel, actions), hero and monster nameplates with pill HP and skill gauges (`GildedGrimoire.Bar`), the boss and floor-progress banner, alert banners (toasts, loot stolen, squad down, squad compromised), the carried-loot pill, the duel banner and the offline-reward popup. Legacy frames are converted with `GildedGrimoire.Reframe`, which strips their old outline first.
- Through the reskinned gothic kit: Summoning, Synthesis, Promotion, the Forge, and every other screen built with `GothicBoxStyle` or `GothicFont`.
