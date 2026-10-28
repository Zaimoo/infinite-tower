---
name: rojo-sync
description: >-
  Sync this repo's Luau files into Roblox Studio with Rojo, using Rokit to
  install the pinned toolchain (rojo, wally from rokit.toml). Use when the user
  asks to sync, serve, live-sync, build a place file, install the toolchain, or
  when edits in src/ are not showing up in Studio.
---

# Rojo sync via Rokit

The project tree is defined in `default.project.json`. It maps `src/ReplicatedStorage`, `src/ServerScriptService` and `src/StarterPlayerScripts`, plus `Packages` (from Wally) under ReplicatedStorage. Tool versions are pinned in `rokit.toml` (`rojo-rbx/rojo@7.7.1`, `UpliftGames/wally@0.3.2`). Never install other versions globally.

All commands run from the repo root in PowerShell.

## 1. Make sure the toolchain is installed

```powershell
Get-Command rokit, rojo -ErrorAction SilentlyContinue
```

If `rokit` is missing, tell the user and have them install it themselves. That's a download-and-run step, so it needs their OK:

```powershell
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
```

Then open a new shell, or add `$env:USERPROFILE\.rokit\bin` to `PATH` for the current one.

Install the pinned tools:

```powershell
rokit install
rojo --version   # expect 7.7.1
```

If `Packages/` is missing, install the Wally dependencies. `default.project.json` references `Packages`, so Rojo fails without it:

```powershell
wally install
```

## 2. Live sync into Studio (normal workflow)

Start the server in the background, since it never exits:

```powershell
rojo serve default.project.json
```

It listens on `localhost:34872`. Then, in Studio:

1. Install the Rojo plugin, version 7.7.x to match the CLI. Either run `rojo plugin install` once, or use the Creator Store plugin.
2. Open the place, click **Rojo → Connect**, and accept the sync diff.

From then on, saving files in `src/` updates Studio live. With Studio MCP connected, you can confirm the sync by reading the changed script with `script_read`.

Things to keep in mind:

- Containers use `$ignoreUnknownInstances: true`, so instances that exist only in Studio (built maps, prefabs) are left alone. Deleting a file deletes the matching script in Studio.
- Edits made in Studio do **not** flow back into files. Make code changes in `src/` only.
- If port 34872 is busy, a server is probably already running. Reuse it, or stop it. You can also pass `--port <n>` and enter the same port in the plugin.

## 3. One-shot build (no Studio connection)

```powershell
rojo build default.project.json -o build/infinite-tower.rbxl
```

Use this to sanity-check that the project file and tree resolve, or to produce a place file to open. Keep `build/` out of commits.

## 4. Sourcemap for luau-lsp (optional)

```powershell
rojo sourcemap default.project.json -o sourcemap.json --include-non-scripts
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `rojo: command not found` after `rokit install` | Add `~\.rokit\bin` to `PATH` or open a new shell. |
| Plugin and server version mismatch | Reinstall the plugin with `rojo plugin install`. |
| `Packages` path not found | Run `wally install`. |
| Changes don't appear | Check the plugin says *Connected* and that the file is under a mapped `src/` folder. |
| Scripts duplicated in Studio | An old copy exists outside Rojo's control. Remove the Studio-side copy, then reconnect. |

After syncing, run `pwsh tests/run.ps1` for the offline checks, and playtest in Studio for visual or multiplayer behaviour.
