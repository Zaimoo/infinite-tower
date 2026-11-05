# Forge workbench: assignment and upgrades

Assumptions and scope

- **React flavor:** the repository already pins `jsdotlua/react@17.2.1` and `react-roblox@17.2.1` through Wally. Use React-lua, not a second TypeScript toolchain.
- **Design tokens:** the placeholders in the brief are resolved from `Shared/Util/GildedGrimoire.luau`, `docs/ui/GILDED_GRIMOIRE.md`, and `ArtifactCatalog`. Preserve the chunky gothic, violet, ink, gold-rail style shown in the screenshots.
- **Equipment:** each hero has one artifact slot, restricted by archetype; each artifact has at most one owner. Duplicate heroes have distinct UUIDs even when their names match.
- **Progression:** artifacts have 1–7 stars, not a separate upgrade level. Rarity and Standard/Enhanced identity stay unchanged. Donors match weapon type and rarity; their stars may differ under the current rules.
- **Inventory:** current server capacity is 50 artifacts and 50 heroes. The supplied grid mounts at most 24 artifacts per page; the selectors were also tested with 1,009 synthetic artifacts.
- **Safety:** equipped and manually locked artifacts remain visible, but cannot be consumed. A lock protects consumption/selling; it does not prevent equipping or upgrading that artifact as the kept target.
- **Delivery:** the production implementation is in `src/StarterPlayerScripts/UI/ForgeWorkbench` and `ForgeWorkbenchController`, with server transactions in `src/ServerScriptService/Core/ForgeTransactions.luau`. HUDController now selects that host. The existing summon and sell screens remain available through it. `reference/forge-overhaul` preserves the isolated review package; its demonstration transport is not used by production. Studio still needs the updated branch synced and playtested.

## 1. Diagnosis

| Current problem | Change | Why |
|---|---|---|
| Assign begins with a weapon, then opens a separate hero drawer; repeated changes repeat navigation. | Retain a selected hero and artifact in one workbench. | A repeated equip needs only candidate → Equip. |
| Owner text is small and absent from upgrade choices. | Use the same portrait/name/identity chip everywhere an artifact appears. | Ownership should survive every change of view or mode. |
| Three Jennas look interchangeable in screenshot 2. | Show name, level, archetype and a short stable ID; use UUIDs internally. | A portrait and display name alone cannot identify duplicate heroes. |
| Current target/material pickers silently omit equipped or locked items. | Start from **All owned**, including protected and incompatible items. Explain unavailable choices inline. | An unavailable choice should be understandable rather than appear missing. |
| The upgrade drawer can be completely empty, with no reason (screenshot 5). | Show all items with protection/type/rarity reasons and eligible counts. | Players can distinguish “none eligible” from “nothing owned.” |
| Target, copies, and result are separated across a target picker, drawer, and slots. | Keep a **TARGET · KEPT** block, a before/after preview, and **MATERIALS · CONSUMED** list together. | The irreversible part becomes explicit. |
| Six material slots imply six available inputs even when five are locked. | Render the actual required count, selected material list, and remaining count. | Future promotion rules do not need visual padlocks. |
| Assignment has no meaningful before/after comparison. | Compare the selected hero's current weapon against the candidate; show signed deltas. | Decisions should use the result for that hero. |
| “Swap” does not explain what happens to the previous owner. | Say **Replace on Jenna** or **Move to Jenna**, with both consequences immediately above. | Moving a weapon currently empties its previous hero's slot; it is not a two-way exchange. |
| Success, delay, and refusal are weak or ambiguous. | Acknowledge only server receipts; retain selections on errors; expose unresolved status. | A click is not evidence that an economy action succeeded. |

## 2. Layout concepts and recommendation

| Concept | Strength | Cost |
|---|---|---|
| Hero roster left, inventory center, separate assign and upgrade workspaces | Excellent hero-first equipping. | A second upgrade workspace repeats the current context-loss problem. |
| Inventory-first, expandable action drawer on each item | Compact on phones and fast for occasional edits. | Reflowing rows and layered drawers make comparison, material selection, and console focus harder. |
| **Persistent inventory + shared detail workbench; optional hero roster** | Keeps selection, ownership, comparisons and upgrade materials in one system. | Requires responsive reflow and explicit focus regions. |

**Choose the third concept.** The inventory is permanent; **Equip / Upgrade** changes only the selected artifact's detail panel. There is no separate upgrade-target picker.

- **PC:** wide windows show roster / inventory / details; medium windows show inventory / details with a hero chooser above. This retains context while leaving room for readable cards.
- **Mobile:** inventory and details are two views of the same retained state. Select a card to open details; choosing materials returns to that same inventory with a pinned target label.
- **Console:** the same regions have stable spatial order and LB/RB shortcuts; there are no hover-only actions or drag requirements. Paging bounds the focus graph.

**Artifacts / Summon remain visible top-level destinations.** Summon opens the existing artifact banner, keeping its costs, pity, odds/catalog and roll behavior. Equip/Upgrade are detail modes within Artifacts. Sell remains a deliberate inventory-management action, outside those primary buttons.

## 3. Shared visual language

States compose. A weapon can be Rare + equipped + locked + selected simultaneously; one border must not attempt to encode all four facts.

| State | Every appearance | Behavior |
|---|---|---|
| Unequipped | `[—] Unequipped`; neutral Deep fill. | Inspectable and eligible as material only if other rules pass. |
| Equipped on hero X | `[E]` + hero portrait + name and short ID; Teal text `#96ECFF`; full owner line in details. | Equippable/movable and upgradeable in place. |
| Selected artifact | `[✓] Selected` + amethyst inset rail `#C084FC`. | Changes comparison/detail content, never commits equipment. |
| Kept upgrade target | **TARGET · KEPT**, identity/owner chip, current → next stars. | Never appears in the consumed list. |
| Selected material | `[−] Material · consumed`; danger text, with name/star count in the removal list. | Tap again or use its 48px Remove button to deselect. |
| Manually locked | `[L] Locked`; lock/protection button in details. | Excluded from auto-fill and consumption; inspection remains available. |
| Equipped protection | `[P] Protected`; owner chip stays visible. | Material selection explains “unequip before using”; no implicit unequip. |
| Invalid material | Reason such as “Requires the same weapon type” or “Requires the same rarity.” | Focusable/inspectable; activation explains refusal without changing materials. |
| Missing or conflicting owner | “Equipped · sync required.” | Treat as protected until an authoritative snapshot resolves it. |
| Gamepad focus | Platform selection adornment outside the control; hover/selection rail brightens. | Distinct from the selected item's persistent text badge. |
| Pending | Primary action says “Waiting for server…”; all mutations are latched. | Filters and inspection can remain usable; no second purchase/upgrade request. |

Rarity uses the **catalog's full 16-tier palette**, a slim rail, and its written rarity name. Common `#B0B0B0`, Uncommon `#4BB543`, Rare `#2980B9`, Superior `#8E44AD`, Exalted `#D35400`, Legendary `#F1C40F`, Mythical `#E74C3C`; use `GetRarityInfo` for later tiers. Dark rarity colors are decoration, not body text.

Use existing fonts: Cinzel Decorative Heavy for headings/actions, Cinzel Bold for body, Cinzel Heavy for numbers. Body 16px, secondary text 14px, headings 22px; retain 48px interactive targets rather than shrinking the entire modal with UIScale. Use parchment `#ECE4F6`, muted `#C4BAD6`, gold `#FFD678`, good `#78FF8C`, bad `#FF6464`, and ink `#0A060E` from the theme.

## 4. Interaction flows, states and transitions

### Selection and equipment

1. Open with the calling hero preselected; otherwise select a deterministic first owned hero. Do not equip anything automatically. A production host may restore the last selected hero.
2. Select any artifact. The selected ID persists across Equip/Upgrade and filters. On mobile, open Details. Selecting does not mutate inventory.
3. Compare current/candidate ownership, power, multiplier, speed and base hero DPS. Incompatible weapons stay visible with a reason; their Equip button is disabled.
4. Press **Equip to X**, **Replace on X**, or **Move to X**. Preview text names the previous owner that becomes empty and the replaced weapon that returns to inventory.
5. Enter `sending`; submit IDs and expected snapshot revision. On success, replace state with the receipt snapshot and show the server's **Undo (10s)** token. On refusal, retain the candidate and show the reason.
6. Unequip acts on the selected hero and returns that weapon to inventory. It also receives equipment undo.
7. Undo is a single server transaction restoring every affected hero/artifact link. Expired, consumed, sold, or subsequently changed equipment invalidates it. Never approximate this with two sequential equip remotes.

For a retained hero: candidate → Equip is two activations. When the candidate is already selected, Equip is one. Initial hero choice and cross-platform navigation are additional inputs; they are not disguised as a one-tap promise.

### Upgrading

1. Select the artifact in the same inventory and press its detail **Upgrade** tab. Equipped and locked targets are allowed and retain their owner/lock.
2. Show target kept, current → next stars/stats, exact Gold/Gems cost and resulting balances. Rarity, variant and hero assignment remain unchanged. For unequipped targets, show artifact stats; do not invent a hero DPS value.
3. **Auto-fill safe materials** selects eligible unequipped/unlocked items by lowest stars, then lowest power, then stable ID. It preserves explicit valid selections and never commits.
4. Alternatively, **Choose materials** switches the inventory's selection role. All owned items remain visible. Protected and wrong-type/rarity cards explain why they cannot be consumed. The target is identified as kept.
5. Remove or replace any material; progress updates immediately. Switching target clears materials. Incoming snapshots remove stale/protected/deleted material selections.
6. **Review upgrade** opens the one destructive confirmation. It lists the target, individual material names/stars, exact before/after stats, costs and permanent-consumption warning. Cancel receives default focus. If the snapshot revision changes, confirmation is disabled until the preview is reviewed again.
7. Confirm once. The server atomically validates, charges, deletes donors and promotes the kept target. Only the success receipt triggers feedback, clears consumed materials and advances the preview to the next rank.

With a target selected, the safe path is Upgrade → Auto-fill → Review → Confirm. The last confirmation intentionally remains: consuming invested items is irreversible.

### Refusal, protection and unresolved delivery

- Protected material → explain owner/lock → optionally visit Equip and explicitly unequip/unlock → return to Upgrade and select it. There is no “consume equipped anyway” shortcut.
- Max rank → show 7★ maximum; no material-selection or promotion actions.
- Insufficient funds/materials → show the missing requirement; preserve selections.
- Profile not ready → host shows a loading state before mounting a valid snapshot; never show a fake empty inventory.
- Request exceeds 12 seconds or transport throws → `uncertain`, with **Check server status**. Reconcile the same RequestId; do not send a new upgrade and risk charging twice.
- Back/B → close modal first, then material mode, then mobile Details, then workbench. Closing does not cancel a transaction already accepted by the server.

## 5. Layout specification

The default window is a centered, bounded modal. The optional expanded layout (`root width ≥ 1120`, when explicitly configured by the host) is:

```text
┌ BLACKSMITH · ARTIFACTS ───────────────────────────── Close ┐
│ [Artifacts] [Summon]   Selected hero [Choose]    Gold/Gems  │
├ Heroes: 232px ─┬ Inventory: remaining ─┬ Details: 34%, cap380│
│ portrait/name  │ Search               │ [Equip] [Upgrade]  │
│ current weapon │ Search/filters  Sort │ Identity + owner   │
│ empty slots    │ Count / material role│ Comparison OR      │
│                │                     │ Target kept        │
│                │ Owned artifact grid │ Before → after     │
│                │                     │ Materials consumed │
│                │ Previous / page/Next │ Exact consequence  │
│                │                     │ Primary action     │
├ Feedback: server result / refusal / unresolved status ─────┤
│ Undo countdown OR input hints                             │
└───────────────────────────────────────────────────────────┘
```

Both details use the same container and identity/ownership components:

```text
EQUIP                              UPGRADE
[Equip] [Upgrade]                  [Equip] [Upgrade]
[Lock / Unlock]                    [Lock / Unlock]
CURRENT · selected hero            TARGET · KEPT + owner
  artifact + owner                 1★ → 2★ · rarity unchanged
CANDIDATE + owner                  Power 540 → 864 (+324)
Power / multiplier / speed / DPS    ×14.50 → ×22.60 (+8.10)
What changes on both heroes        +13.0% → +13.0% (=)
[Equip / Replace / Move to X]       Owner base DPS, when equipped
[Unequip selected hero]            500 Gold + 0 Gems; balances
                                   MATERIALS · CONSUMED 1/1
                                   [Name · stars · Remove]
                                   [Choose] [Auto-fill safe]
                                   [Review upgrade to 2★]
```

Mobile (`root width < 760`):

```text
Title                           Close
[Artifacts] [Summon]
[Selected hero / choose]
[Inventory] [Details]

INVENTORY                       DETAILS
[Search/filters] [Sort]          [Equip] [Upgrade]
Count / kept target label       Same detail components in
Responsive grid                 a vertical scrolling panel
Previous / page / Next          Choose materials → Inventory

Feedback / Undo (retained across both views)
```

Concrete sizing used by the package:

| Element | Roblox sizing / spacing |
|---|---|
| Screen | `ScreenGui.ScreenInsets = CoreUISafeInsets`, `ResetOnSpawn = false`, sibling ZIndex. |
| Root | `Size = UDim2.fromScale(0.9,0.86)`, centered, `UISizeConstraint.MaxSize=(960,640)` by default. Leaves world-visible margins; no whole-screen downscaling. The host may explicitly opt into a wider `MaxWindowSize`. |
| Spacing | 4/8/12/16/24px scale; standard panel padding 16, grid gap 12, stack gaps 8 or 12. |
| Body top | 112px desktop, 224px phone; short windows (<520px height) use 64px desktop / 120px phone headers. Artifacts/Summon remain accessible in each layout. |
| Wide roster | 232px; hide as a column below 1120px and expose the same choices through the hero button. |
| Details | `clamp(width*0.34,304,380)`; full available width on phone. |
| Inventory | Remaining width; columns = `floor((availableWidth+12)/(176+12))`, minimum one. |
| Artifact card | Nominal minimum width 176px; 360px high to accommodate owner/protection/selection without overlay collisions. |
| Hero row | 112px high with a 48px portrait area. Entire row activates. |
| Buttons | 48px high; at least 44px wide. Labels can wrap. |
| Scrolling | Independent vertical inventory/details/roster scrolling; `UIListLayout`/`UIGridLayout`, padding, `AutomaticCanvasSize=Y`. |
| Paging | Maximum 24 mounted artifacts; previous/page/next footer 60px. Filters return to page 1. |
| Feedback | 76px idle; 124px while showing Undo or reconciliation. |
| Confirmation | 94% width / 92% height, capped 620×760, internally scrolling, Cancel first. |
| Shape | Window radius16, card/panel12, row/button10; ink2–3.5px, inset rail1.4px at3px. |
| Layers | Workbench DisplayOrder80; dialog subtree ZIndex100; only scroll regions clip descendants. |

Short landscape windows prioritize controls and scrolling rather than reducing text or touch sizes. The package was measured at root sizes 320×360, 320×568, 390×844, 844×390, 1024×768, and 1440×900. These are layout probes, not hardware certification.

## 6. Motion and feedback specification

Use TweenService and the existing `UIFeel` preference/audio layer; no additional animation dependency is needed.

| Interaction | Motion | Purpose |
|---|---|---|
| Hover / gamepad focus | UIScale 1 → 1.015, 120ms, Quad Out; brighten inset rail. | Acknowledge the control without shifting grid layout. |
| Press | UIScale → .98, 60ms Quad Out; release 100ms to focus/idle scale. | Immediate tactile response across input types. |
| Select artifact / toggle material | Badge and rail update immediately; retain scroll position. | Make selection speed independent of animation. |
| Equip receipt | Updated owner chips immediately; feedback scale .98 → 1, 220ms Back Out. | Feedback reflects acknowledged state. |
| Upgrade receipt | New star/stats immediately; same 220ms feedback pop, optional existing StarTick sound. | Celebrate success without delaying interaction. |
| Tab / responsive pane | Immediate content change with persistent state. An optional panel opacity fade may be ≤100ms. | Avoid making mode changes feel like navigation to another system. |
| Confirmation | Immediate modal/focus transfer; optional 120ms Quad Out opacity. | Keep destructive actions legible rather than theatrical. |
| Refusal | Persistent readable reason; optional Error sound, no shake. | Explain how to recover without punishment or ambiguity. |
| Undo | Immediate receipt update; visible seconds remaining. | Make recovery predictable. |
| Slow request | Text/status changes at12s, no fabricated progress bar. | Communicate uncertainty honestly. |

The package implements hover/press and receipt pops. Optional panel fades and decorative upgrade effects are specified but not required for correctness. Reduced motion skips positional/scale effects through `UIFeel.ReducedMotion`; state text remains visible. Empty audio slots stay silent; respect the shared SFX volume. Haptics may reuse the existing UIFeel layer after a successful receipt; do not require them to understand state.

## 7. React component architecture

```text
App (ScreenGui; responsive/focus/dialog state)
├ useForge (authoritative snapshot + pending request lifecycle)
├ HeroSlot[] (same component inside wide roster or hero chooser)
├ InventoryGrid (24-item pages, scroll and focus reveal)
│ └ ArtifactCard
│   ├ Preview (existing ArtifactPreview, owned cleanup)
│   └ StateBadges (owner portrait/identity, protection, selection)
├ Detail [Equip | Upgrade]
│ ├ ItemSummary / StateBadges
│ ├ ComparisonPanel → StatRow[]
│ ├ UpgradePreviewPanel → StatRow[] / selected material Remove buttons
│ └ ActionFlow → reason + primary Button
├ Dialog (filters, heroes, destructive review; focus restoration)
└ Feedback + UndoButton
```

State is split deliberately:

```luau
-- Server-owned, replaced only by authoritative snapshots:
snapshot = { Revision, Artifacts = {[uuid] = artifact}, Heroes = {[uuid] = hero}, Gold, Gems }

-- Local intent / presentation:
heroId: string?
targetId: string?
mode: "EQUIP" | "UPGRADE"
materialIds: {string}
filter = { Query, Ownership, Rarity, WeaponType, Sort }
page: number
mobilePane: "INVENTORY" | "DETAILS"
materialMode: boolean
dialog: string?

-- Async state:
phase: "idle" | "sending" | "uncertain"
pendingCommand: Command? -- ref latch, not just a delayed React state update
undo: {Token: string, ExpiresAt: number}?
```

`Model` is pure selection/filtering logic; `useForge` handles receipts, revision checks, duplicate-submit latching, cleanup and reconciliation. Components render props and emit intentions. `useMemo` caches sorting/filtering, and only the small UndoButton ticks once per second. No gameplay state is written by the render functions.

The package uses [React-lua hooks and bindings conventions](https://github.com/jsdotlua/react-lua/blob/main/docs/api-reference/react.md) and mounts through [ReactRoblox.createRoot](https://github.com/Roblox/react-luau/blob/main/docs/api-reference/react-roblox.md). Native layouts and `Activated` keep the components independent of browser/CSS behavior.

## 8. React code and integration boundary

The complete code is in `reference/forge-overhaul`, rather than an abbreviated snippet that omits safety handling:

| File | Responsibility |
|---|---|
| `ForgeWorkbench/Types.luau` | Artifact, hero, snapshot, command, receipt, transport and App props. |
| `ForgeWorkbench/Tokens.luau` | Existing Grimoire theme plus workbench geometry. |
| `ForgeWorkbench/Model.luau` | Ownership protection, eligibility, comparison inputs, deterministic sort/search/filters/recommendations. |
| `ForgeWorkbench/Components.luau` | Hero slot, artifact card/badges, inventory grid, comparison, upgrade preview and shared action flow. |
| `ForgeWorkbench/useForge.luau` | Equipment/upgrade/lock/undo intent, authoritative receipts, request latch and reconciliation. |
| `ForgeWorkbench/App.luau` | Responsive composition, safe confirmation, filters, gamepad input scope and feedback. |
| `Fixture.luau`, `DemoTransport.luau` | Synthetic review data and local authority simulation, clearly excluded from production integration. |
| `workbench.spec.luau`, `Verify.ps1` | Behavioral tests using the repository's actual catalog and stat functions. |
| `Build-Preview.ps1`, `preview.project.json` | Isolated Studio MCP review bundle and buildable model package. |

Representative component contracts, all implemented in the files:

```luau
e(C.HeroSlot, {
    Snapshot = snapshot, Hero = hero, Selected = heroId == hero.UUID,
    OnSelect = function() setHeroId(hero.UUID) end, Order = 1,
})

e(C.ArtifactCard, {
    Snapshot = snapshot, Artifact = artifact,
    Selected = targetId == artifact.UUID, Material = false,
    Recommended = bestId == artifact.UUID, Order = 1,
    OnSelect = function() selectTarget(artifact.UUID) end,
})

e(C.ComparisonPanel, { Snapshot = snapshot, HeroId = heroId, Artifact = artifact })
e(C.UpgradePreviewPanel, {
    Snapshot = snapshot, Target = artifact, MaterialIds = materialIds,
    OnRemove = toggleMaterial,
})
e(C.ActionFlow, {
    Label = "Review upgrade to 2★", Reason = upgradeReason,
    Busy = phase ~= "idle", OnActivate = openConfirmation,
})
```

To integrate, install `ForgeWorkbench` under `StarterPlayerScripts/UI` so it can reuse `Hud.Portrait`, `ArtifactPreview` and `UIFeel`. Mount App into a dedicated client container under PlayerGui:

```luau
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local App = require(script.Parent.ForgeWorkbench.App)
local root = ReactRoblox.createRoot(container)
root:render(React.createElement(App, {
    Snapshot = authoritativeSnapshot,
    Transport = forgeTransport,
    InitialHeroId = callingHeroId,
    OnSnapshot = acceptNewSnapshot,
    OnClose = closeWorkbench,
    OnSummon = openExistingArtifactSummon,
}))
-- The owning controller calls root:unmount() when disposing the workbench.
```

`ForgeWorkbenchController` replaces the legacy Assign/Upgrade destinations with this same mounted workbench and passes the intended initial mode when opening it. `OnSummon` closes the workbench and opens the existing ForgeController with `Open("SUMMON")`. Sell uses the existing sell screen and returns to the workbench on cancellation/completion. The host retains the HUD's existing modal arbitration. The reference demo files remain outside the production tree.

### Production transport

The legacy `RequestEquipArtifact`, `RequestUnequipArtifact`, `RequestUpgradeArtifact` and lock endpoints remain available. The new `ForgeWorkbenchRequest` endpoint implements STATE, EXECUTE and RECONCILE for the typed transport. `ForgeTransactions` performs non-yielding validation, mutation and receipt recording before DataManager synchronizes or awards onboarding progress. Cached successes do not repeat those side effects.

`Execute(command)` must return `{RequestId, Ok, Message, Snapshot, UndoToken?, UndoExpiresAt?}`. `Reconcile(requestId)` returns that same request's terminal receipt. The production bridge must:

1. Authenticate the requesting player and their profile, enforce plot/onboarding rules, rate-limit calls, bound/validate every field, check finite integer revisions and donor counts, and reject duplicate IDs within a donor list.
2. Resolve all IDs from the player's server profile. Repeat weapon compatibility and reciprocal ownership checks; never trust the client's displayed eligibility, costs, stars or stats.
3. Track a server revision covering relevant inventory, equipment, hero-stat and lock changes, including legacy systems. Passive currency changes leave that structural revision stable; every economy commit revalidates the current server balances atomically. Reject stale structural previews with a fresh snapshot before changing anything.
4. Deduplicate RequestId for the player/session. Serialize conflicting mutations; cache the receipt before any yield after commit. Keep IDs/receipts long enough for reconnect/timeout reconciliation, with a bounded cache and cleanup on player removal.
5. For promotion, reuse `WeaponPromotion.Promote` inside the serialized operation. Its existing non-yielding validation/mutation protects equipped and locked donors and retains the target. Synchronize the profile after committing.
6. For equipment, atomically maintain both `EquippedHeroUUID` and `EquippedArtifactUUID`. Record the inverse for every affected link; an undo token is player-bound, single-use, expires after10s, and checks the expected post-change state/revision. Never undo a promotion or restore a consumed/sold artifact.
7. Project full stat inputs into snapshots: hero template, level, stars, rarity and quality; artifact template, rarity and stars. Preserve any extra fields required by the canonical stat functions. Base DPS is labeled as excluding temporary buffs; final live combat buffs are outside this comparison.
8. Send immutable snapshot tables to the client. A receipt for an older revision must not replace a newer snapshot. A reconnect loads server state rather than replaying local commands.

These requirements are implemented by the production host and server module on this branch. Runtime Studio installation/playtest is still pending. `DemoTransport` remains a simulation used only by the reference review package.

## 9. Edge cases, QoL, accessibility and performance

| Area | Decision and recovery |
|---|---|
| Gamepad | Explicit region order roster → inventory → details. A activates, B backs out one level; LB/RB moves regions. Modal focus stays inside, starts on a safe Cancel/Back control and restores on close. `SelectionGained` scrolls a focused card/button into view. |
| Focus after filters/pages | Clamp the page, select a visible control in the new inventory region, and retain target/material UUIDs independent of their visibility. The host must test this on actual controllers. |
| Touch | 48px controls, no double-click/hover/drag requirement, no globally scaled-down modal. On phones search and filters use a full dialog. |
| Tooltips | Essential ownership/protection/reasons are inline. Full owner details are always in the detail panel; hover hints may supplement them, never replace them. A further long-name tooltip can reuse the game's tooltip layer. |
| Color accessibility | Written rarity, E/L/P/✓/− markers, portrait/identity, and ↑/↓/= signed stat deltas carry meaning independently of hue. Keep text on an opaque dark surface. |
| Duplicate/long hero names | Stable short ID and full detail owner line disambiguate. Localized text may wrap; retain fixed interactive targets. Product localization should replace literal English labels with localization keys. |
| No heroes | Allow artifact inspection/upgrading; show a clear hero-empty state and disable equip. |
| No eligible materials | Keep protected/incompatible owned items visible and explain why; auto-fill never falls back to equipped items. |
| Higher-star/Enhanced donors | Auto-fill preserves investment by spending low stars then low power first. Manual consumption is permitted under existing rules, but the review lists each donor's stars and name. |
| Lock changes during review | Revision invalidates the confirmation and eligibility is recomputed. The server remains decisive. |
| Max stars | Show max state and no next-rank action, rather than displaying a false improvement. |
| Slow/offline/reconnect | Reconcile a known RequestId. Do not clear materials or celebrate before acknowledgement; reload authoritative state on reconnect. |
| Audio/haptics | Reuse SFX settings and optional UIFeel cues; no sound-only result, new hard-coded asset IDs, or mandatory haptics. |
| Reduced motion | Keep instantaneous state changes and text; suppress scale/position animation. |
| Large inventories | 24 mounted cards per page, stable UUID keys, memoized filters/sorts, one-second undo timer isolated to its component. Prefer cached thumbnails for inventories beyond the current cap; reserve model viewports for visible/selected items. |
| Performance growth | At50 items the simple ownership scans are small. If the cap grows into thousands, build one owner-by-artifact index per snapshot instead of repeatedly scanning heroes, and profile before choosing virtualization. |
| Cleanup | Preview viewports, tweens, input context and connections are disposed on unmount. Pending server actions are not silently canceled by hiding the UI. |

Focus behavior uses Roblox's [SelectedObject/Select APIs](https://create.roblox.com/docs/reference/engine/classes/GuiService), and control selection/ordering follows the [GuiObject selection APIs](https://create.roblox.com/docs/reference/engine/classes/GuiObject). The normal client mount must live under PlayerGui; the isolated Edit-mode CoreGui harness does not certify real gamepad input routing.

### Verification recorded for this delivery

- All package Luau files compile with the repository's Luau0.743 compiler.
- The repository regression suite passes; 12 new workbench behavioral cases pass against the actual catalog/stat functions.
- Studio MCP confirmed the open place's React packages, Grimoire theme, 84 templates, 7-star cap and first promotion costs.
- The isolated React package mounted in Edit-mode CoreGui against synthetic data; no player profile or production script was modified. Geometry probes covered24 Equip/Upgrade × inventory/details × size configurations, with no TextButton smaller than44px, no `TextFits` failures and no captured runtime errors. Those probes were followed by a smaller default-window revision in response to user review.
- The revised default measured960×537.5 within the actual1590×625 viewport, with315px side margins and43.75px vertical margins. The Summon destination was visible and its handoff opened the real existing banner code in a synthetic, purchase-disabled review (791×545 fitted banner window). Probe overrides must always be restored before leaving a preview visible.
- Production validation adds13 authoritative transaction tests, including server-only protection checks, receipt deduplication without repeated onboarding side effects, safe undo, live currency checks, stale revisions, malformed requests and rate limiting.
- Remaining release QA: sync this branch into Studio; playtest actual mouse/touch/gamepad actions, modal/focus paths and network failures; visually verify loaded fonts and localized text on device simulators. Edit-mode viewport capture omitted the CoreGui review, and Studio reported Cinzel font-loading warnings, so this is not a claim of completed visual/hardware certification.
