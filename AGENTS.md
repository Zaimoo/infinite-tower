# Roblox development

Use the relevant skills from https://github.com/EL4CTEO/roblox-skills whenever applicable. They are installed in C:/Users/msi/.codex/skills/roblox-*/SKILL.md. Read applicable skills before working on their topics.

## Tooling & Sync Workflow
- **Always use Roblox Tooling:** Always adhere to the `roblox-tooling` skill practices. Manage dependencies with Wally (`wally.toml` / `wally.lock`), pin CLI tools in `rokit.toml`, and maintain project mappings in `default.project.json`.
- **Rojo Live Sync & Studio Plugin:** Run `rojo serve` and connect via the **Rojo Studio plugin** in Roblox Studio to maintain continuous two-way synchronization between disk and the live place.
- **Studio MCP Integration:** Utilize Roblox Studio MCP tools (`execute_luau`, `get_studio_state`, `start_stop_play`, `get_console_output`, etc.) to run automated test suites, inspect DataModel state, verify parity, and conduct automated playtest checks.
- **Authoritative Source of Truth:** Git is the authoritative source of truth for code and configuration. Before committing, always verify project integrity with `rojo build -o build.rbxl`.
