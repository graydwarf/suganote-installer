# Suganote Installer

Standalone installer/updater built with Godot 4.5. Configured at build time via JSON files — the codebase is app-agnostic.

## Modes

- `--install` (default) - First-time install with location picker
- `--upgrade <manifest_path>` - Upgrade from pending-upgrade.json manifest
- `--rollback <install_dir>` - Restore .backup files in the given directory

## Setup

1. Copy `app-config.template.json` to `app-config.json` and set your app's name, exe, and logo
2. Copy `license-config.template.json` to `license-config.json` and fill in your Supabase licensing credentials
3. Open in Godot 4.5 editor

## CI/CD

The GitHub Actions workflow creates both config files from repository variables and secrets:

**Variables** (Settings > Variables):
- `APP_NAME` — Display name (e.g., "Suganote")
- `APP_EXE_NAME` — Executable filename (e.g., "Suganote.exe")
- `APP_PCK_NAME` — Pack filename (e.g., "Suganote.pck")
- `SUPABASE_LICENSE_URL` — Supabase project URL for version checking

**Secrets** (Settings > Secrets):
- `SUPABASE_LICENSE_PUBLISHABLE_KEY` — Supabase publishable (anon) key

## Addon

Uses [godot-installer](https://github.com/graydwarf/godot-installer) as a git submodule at `addons/godot-installer/`. After cloning, run:

```bash
git submodule update --init
```
