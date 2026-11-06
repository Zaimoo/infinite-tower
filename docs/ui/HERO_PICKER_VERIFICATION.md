# Shared hero picker verification

The shared `HeroSelectionDrawer` / `HeroPickerCard` presentation is used by Synthesis,
legacy Equip Artifact, and the current React Forge workbench through its `HeroPicker` adapter.
Artifact target/material dialogs and Promotion keep their existing implementations.

## Automated verification (2026-11-06)

- Compiled all production Luau sources with the installed official Luau CLI.
- Ran the existing unchanged-source CLI harness: 59 Pit cases (including two new
  recipient-status cases), Forge specs, and 13 Forge authority cases passed.
- Ran `rojo build -o build.rbxl` and `git diff --check` successfully.
- Studio Client checks: 23 synthesis transitions/layout/focus assertions,
  8 artifact controller assertions, and 7 React adapter assertions passed.
- Desktop layout queried in Studio: five columns, two complete rows, 44px actions.
- Phone portrait at 401×778: two columns, two complete rows, 144×44px actions.
- Phone landscape prototype was inspected; its clipped action buttons prompted the compact
  layout. Final dimensions are queried directly; physical input validation remains pending.

## Reproduce client checks

Run each file's contents using Studio MCP `execute_luau` with `datamodel_type = Client`:

1. `tests/studio-hero-selection-client.luau`
2. `tests/studio-artifact-hero-picker-client.luau`
3. `tests/studio-react-hero-picker-client.luau`

The tests use fake remotes/callbacks and never consume inventory. They use synced UI modules
by default, or an isolated `PlayerScripts.SelectionTestModules` folder if provided.
The synthesis test leaves its fixture in `_G.SelectionFlowTest` for visual inspection;
close it and destroy its `Gui` afterward. Stop Play mode after testing.

## Environment limits

Rojo was already serving on localhost:34872. The Studio plugin refused connection because
`ServerStorage.__Rojo_SessionLock` belonged to another active collaborator. That lock was
left untouched. Studio tests used client-only copies of the on-disk UI modules, discarded
when Play stopped; production source parity in the shared place is not verified.

The Mac became locked during device/input testing. Studio's physical mouse/gamepad and
screen-capture tools stalled; actual mouse, touch, and controller interaction still need a
pass on an unlocked Mac. The simulator was reset and Play stopped. No place was published.
