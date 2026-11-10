# Tower climb streak implementation plan

Give players three chances to understand the streak during a normal run. Show the bonus when they clear a floor, explain what the next choice does, and show what the streak earned when they bank a relic.

## Fit with the UI kit

The floor banner already uses the plum, ink, gold rail, and Cinzel HUD style. Its helpers still carry the historical `Glass` name. Match the rendered banner and the [Brighter Grimoire HUD spec](UI_OVERHAUL_PLAN.md#31-surfaces). The older Clear Glass examples in the [theme guide](GILDED_GRIMOIRE.md#clear-glass-hud-zones) show the previous styling.

Build the streak row inside the existing floor banner’s layout. Use `Kit.Tokens` for type and spacing, the drawn `GrimoireIcons.Spark` glyph, and jade for positive feedback. Give the cap a gold accent and a written `MAX` label. Keep the bonus in text at every size. Use the existing Ink and gold rail on the parent rather than framing the streak row as another full card. If the row needs a fill, use the kit’s inset tone.

Reuse `Kit.Notify` for the relic receipt, `Kit.Callout` for the optional portal hint, and the existing `UIFeel` and `Kit.Motion` effects. Keep the badge display-only so it stays out of the keyboard and gamepad focus order.

## 1. Ship the streak row and relic receipt

### Streak row

- In [HUDController](../../src/StarterPlayerScripts/UI/HUDController.client.luau), mount the row once and subscribe to `TowerRemotes.RunState`. Read `Streak` and `StreakMultiplier` from [TowerRunService](../../src/ServerScriptService/Combat/TowerRunService.luau). The server also publishes on earnings and sanctuary banking, so compare the previous and current streak values before updating or animating the row.
- Show **3-floor streak · +30% relic Gold & Gems**. On narrow screens, wrap it into two lines at the kit’s 13 px minimum. Let the banner grow with the row and keep the boss HP and kill progress as the main lines. Hide the row at zero and outside the personal tower run, including in the hub, during raids, and when viewing a stationed squad from elsewhere. Follow the floor HUD’s modal visibility.
- Use a quick `UIFeel.Pop` when the bonus increases. Play the kit success effect once when the run reaches **MAX +100%** for the first time. The floor count can continue to rise above 10, with the bonus fixed at +100%. A same-floor clear, earning tick, or bank event keeps the badge steady. Reduce Motion gets the same text and colour states without animation.
- After the first credited clear of the play session, show a short inline tip in the floor HUD. **Clear the next floor to grow your streak. Bank relics at a sanctuary to collect the bonus.** Dismiss it on the next clear or when leaving the floor. Keep the onboarding quest order and save data as they are.

### Bank receipt

- Calculate the breakdown inside [RelicService.awardRelicPayout](../../src/ServerScriptService/ExtractionAndSocial/RelicService.server.luau), which both extraction paths already use. Capture the streak multiplier at the moment of payout. For each currency, calculate the streak contribution as `credited total - rounded pre-streak payout`. Use the same floor, Market, and extraction factors as the existing credit calculation. Keep Promotion Stones as a separate reward.
- Extend the existing `SystemToast` route with an optional structured relic receipt. Keep the plain message as the fallback for other consumers. Display one reward toast per bank in [Kit.Notify](../../src/StarterPlayerScripts/UI/Kit/Notify.luau) and suppress identical-message coalescing for this receipt type so each bonus is tied to its payout.
- Add a receipt layout to the existing toast stack with a title and wrapping reward lines. The normal toast path stays single-line. Bound the receipt to the safe viewport width, preserve exact integer amounts, and check its placement when floor-clear and relic-drop notifications arrive together. Use the existing reward icon and chime.
- Example for the Gem line of a Floor 50 Apex Core receipt at a three-floor streak, assuming normal extraction. **13,559 Gems · +3,129 from streak**. The Gold line follows the same format. Omit the bonus phrase for a currency when its streak contribution is zero. Both lines include the bonus in the credited total.

## 2. Explain the next choice and the end of the run

### Portal hints

Keep the existing hold prompts and travel checks in [CombatSimulation](../../src/ServerScriptService/Combat/CombatSimulation.server.luau). Give the two Apex prompts a stable action identifier and floor ID. Show a single local `Kit.Callout` next to the floor HUD while an eligible prompt is visible. Use the same prompt lifecycle already used by [HudApp](../../src/StarterPlayerScripts/UI/Hud/HudApp.luau). Clear the hint on prompt hide, travel, modal open, or run end.

Add `LastClearedFloor` to the server’s run-state payload before implementing these hints. Base the preview on the last credited clear, the prompt’s destination, and the shared streak rules. A previously unlocked floor can expose the portal without counting as this run’s last clear.

| Player choice | Example copy |
| --- | --- |
| Ascend after a three-floor streak | **Clear Floor 14 for +40% relic rewards** |
| Rerun the last credited floor | **Rerun Floor 13 · Keeps +30%** |
| Clear a floor that skips or backtracks from the sequence | **Clearing this floor starts a new streak** |
| Ascend at the payout cap | **Clear Floor 24 · Relic bonus stays at max** |
| Floor 50 return portal | **Return to Hub · Ends your run** |

The hint describes what the next **clear** will do. Entering a floor alone leaves the streak alone. On Floor 50, the Rerun hint still shows the retained bonus when Floor 50 was the last credited clear.

### Run end

- Use the existing `RunSummary` reason to distinguish a return from a wipe. On a normal return, let the existing summary toast report **Best streak · 3 floors**. On a wipe, fold **Streak ended · Banked loot is safe** into the existing defeat feedback when a streak was active. Keep any actual unbanked loss in the message. Use the summary’s reason and values so a zeroed run-state packet cannot erase the explanation.
- A sanctuary bank does not end the run. The streak row remains visible and keeps its current bonus.

## Verification before release

| Check | Pass condition |
| --- | --- |
| Beginner loop | First clear shows +10% and the tip. The next sequential clear shows +20%. Clearing the same floor again preserves the amount without another pulse. |
| Out-of-order, cap, and Floor 50 | Skipped or backward clears restart at +10%. Clear 10 celebrates once, and clear 11 stays at +100%. A fresh Floor 50 rerun stays at +10%. A 48 → 49 → 50 climb followed by a 50 rerun keeps +30%. No hint points to Floor 51. |
| Payout accuracy | Receipt totals match the profile balance changes. Check zero streak, an active streak, the cap, rounding, Market Gold, Promotion Stones, rapid banks, and both extraction paths. A sanctuary bank preserves the streak. |
| Leaving and re-entering | Return, wipe, raid, respawn, and remote squad viewing never show a stale badge or portal hint. A wipe has one explanation and correctly distinguishes banked and unbanked earnings. |
| Layout and input | Check 1920×1080, 1366×768, and phone portrait and landscape in Studio. With the top toast stack occupied, the bonus, boss HP, and portal prompt remain readable and reachable. Check touch, keyboard, gamepad, long relic names, and Reduce Motion. |

Extend the [tower run tests](../../tests/tower-run-loop.spec.luau) and [kit tests](../../tests/ui-kit.spec.luau) for payout rounding, preview rules, and receipt stacking. Run the repo’s compile and spec runner and `rojo build -o build.rbxl`, then use the Rojo-synced Studio place and MCP for the end-to-end checks and screenshots.

This is a presentation change. The current +10% per sequential clear, +100% cap, payout tables, and same-floor farming behavior define the acceptance baseline. The larger run-summary modal and any public relic billboard previews are outside this plan.
