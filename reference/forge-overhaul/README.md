# Forge workbench review package

The production implementation is now in `src/StarterPlayerScripts/UI/ForgeWorkbench`, hosted by `ForgeWorkbenchController`, and backed by `ServerScriptService/Core/ForgeTransactions`. HUDController selects that host. This folder remains the isolated review/demo package; it is not mounted into production. See the specification for the current implementation and remaining Studio playtest work.

Read the [nine-part design specification](../../docs/ui/FORGE_WORKBENCH_REDESIGN.md) first. It includes the diagnosis, three concepts and recommendation, state language, flows, layout/motion specs, architecture, code index, and edge cases.

The `ForgeWorkbench` folder contains real React-lua components that reuse this project's Grimoire tokens, hero portraits, artifact previews, stat formulas, and UIFeel preferences. Its default modal is capped at960×640 with screen margins. The top-level Summon destination hands off to the existing artifact banner. It is deliberately outside the live Rojo source tree. The current ForgeController has not been replaced.

`DemoTransport` and `Fixture` are local simulations only. Production integration requires the authoritative receipt/revision/idempotency/undo contract in section8 of the specification. No real player inventory is used by the review harness.

Run from the repository root in PowerShell:

```powershell
./reference/forge-overhaul/Verify.ps1
./reference/forge-overhaul/Build-Preview.ps1
rojo build reference/forge-overhaul/preview.project.json -o "$env:TEMP/forge-workbench-review.rbxm"
```

`Build-Preview.ps1` writes a Luau script to the temporary directory. Execute its contents with Studio MCP `execute_luau` in **Edit** for a temporary CoreGui review. It does not install modules, edit place scripts or access profiles. It automatically closes after five minutes; close immediately with:

```luau
if _G.ForgeWorkbenchReview then _G.ForgeWorkbenchReview.Close() end
```

The Edit harness supplies a synthetic PlayerScripts parent solely for input-context construction. Real input/focus QA must use the normal client mount under PlayerGui. Studio's edit viewport screenshot tool omits the CoreGui overlay, so geometry probes are supplementary checks, not visual certification.

To review the initial Upgrade composition after mounting:

```luau
_G.ForgeWorkbenchReview.Render(nil, nil, "UPGRADE")
```

When probing a temporary root size, restore the fitted size immediately afterward, including on failure. Do not leave the review at an oversized test resolution:

```luau
local root = _G.ForgeWorkbenchReview.Host.ForgeWorkbench.Root
local originalSize = root.Size
local ok, message = pcall(function()
    root.Size = UDim2.fromOffset(390, 500)
    task.wait(0.1)
    -- Inspect layout geometry here.
end)
root.Size = originalSize
assert(ok, message)
```

The host example is in the specification. Install only the `ForgeWorkbench` folder under `StarterPlayerScripts/UI`, then provide a real transport, snapshots from the profile controller, and `OnSummon` to open the existing artifact banner. Keep the fixture, demo transport and preview harness outside production. In Edit mode, the review's Summon route reuses the existing banner with fake remotes and disables summoning; during play it hands off to an existing `_G.ForgeController` when available.
