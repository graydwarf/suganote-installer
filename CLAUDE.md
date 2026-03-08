# Suganote Installer - Project Context

## Project Overview
Standalone Godot 4.5 installer/updater app. App identity (name, exe, logo) is configured at build time via `app-config.json`, not hardcoded. Uses the `godot-installer` addon for all install/upgrade/rollback logic.

## Git Submodules

### godot-installer addon (`addons/godot-installer/`)
- **Source repo**: `github.com/graydwarf/godot-installer`
- **This is a git submodule** — do NOT edit files in `addons/godot-installer/` directly
- **To make addon changes**: Clone the `godot-installer` repo, make changes there, push, then update the submodule here:
  ```bash
  git submodule update --remote addons/godot-installer
  git add addons/godot-installer
  git commit -m "chore: Update godot-installer submodule"
  ```
- **After cloning or pulling**: Run `git submodule update --init` to fetch submodule content

## Related Projects
- **`github.com/graydwarf/suganote`** — Main Suganote app (also uses godot-installer as submodule)
- **`github.com/graydwarf/godot-installer`** — Reusable installer addon (the shared dependency)

## Architecture
- `scenes/main.gd` — Shell that loads config from JSON, parses CLI, wires UI
- `addons/godot-installer/` — All installer logic (submodule, do not edit here)
- `assets/` — Branding (logo, icons)
- `app-config.json` — App identity (gitignored, created by CI or from template)
- `license-config.json` — Supabase licensing keys (gitignored, created by CI or from template)

## Build-Time Configuration
Two JSON files configure the installer at build time (both gitignored, CI creates from variables/secrets):

- **`app-config.json`** — App name, exe name, pck name, accent color, logo path
- **`license-config.json`** — Supabase URL and publishable key for version checking

Templates are committed as `app-config.template.json` and `license-config.template.json`.

## Three Installer Modes
1. **First Install** (`--install`, default) — Shows location picker, fetches latest version, downloads and extracts
2. **Upgrade** (`--upgrade <manifest_path>`) — Reads pending-upgrade.json, downloads, verifies, backs up, extracts, launches, polls for success
3. **Rollback** (`--rollback <install_dir>`) — Restores .backup files in the given directory

## Technical Context
- **Platform**: Windows
- **Godot Version**: 4.5.stable
- **Godot Language**: GDScript
