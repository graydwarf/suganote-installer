# Suganote Installer

Standalone installer/updater for Suganote, built with Godot 4.5.

## Modes

- `--install` (default) - First-time install with location picker
- `--upgrade <manifest_path>` - Upgrade from pending-upgrade.json manifest
- `--rollback <install_dir>` - Restore .backup files in the given directory

## Setup

1. Copy `license-config.template.json` to `license-config.json`
2. Fill in your Supabase licensing project URL and anon key
3. Open in Godot 4.5 editor

## Addon

The `addons/godot-installer/` addon is copied from `suganote-main`. Current version: v1.0.0 (commit aea061c).
