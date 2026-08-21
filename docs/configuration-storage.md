# Configuration storage

This document describes the storage layout of the pinned
`sing-box-for-desktop` revision packaged by this flake.

## User data

On Linux, Electron sets the application data directory to
`$XDG_CONFIG_HOME/sing-box`, falling back to `~/.config/sing-box`. The
directory is created with mode `0700` and must be owned by the current user.

The desktop application stores structured state in `settings.db`, a SQLite
database with three tables:

- `preferences` stores JSON-encoded values as blobs keyed by name.
- `profiles` stores ordered profile metadata.
- `remote_servers` stores remote dashboard server connections.

Profile configuration bodies are separate UTF-8 JSON files under
`profiles/<profile-id>.json`. The selected profile is stored as the
`selected_profile_id` preference.

The requested preference mapping is:

| UI setting | Storage | Upstream default |
| --- | --- | --- |
| Enable Tray | `preferences.tray_enabled` | `true` |
| Keep Tray in Background | `preferences.tray_in_background` | `true` |
| Language | `preferences.language` | absent (`auto`) |
| Appearance | `preferences.theme` | absent (`auto`) |
| Theme/accent | `preferences.accent` | absent (`default`) |
| Disable Deprecated Warnings | `preferences.disable-deprecated-warnings` | `false` |
| Terminal Configuration | `preferences.terminal-config` | see below |

`terminal-config` is one JSON object with these fields:

| Field | Upstream default |
| --- | --- |
| `symbolBarAlwaysShow` | `false` |
| `lightThemeName` | `Alabaster` |
| `darkThemeName` | `Afterglow` |
| `lightThemeCustom` | empty JSON string |
| `darkThemeCustom` | empty JSON string |
| `fontFamily` | empty string (the bundled monospace stack) |
| `fontSize` | `13` |

## Start at login

Start At Login is not stored in SQLite. On Linux the application creates or
removes `$XDG_CONFIG_HOME/autostart/sing-box.desktop` (falling back to
`~/.config/autostart/sing-box.desktop`). When the option is managed, the Nix
wrapper makes the application report the declarative value and removes any
per-user entry that could override it. The NixOS module installs a system-wide
`/etc/xdg/autostart/sing-box.desktop` only when the value is true, so the first
launch does not need to happen manually and false leaves no stale user override.

## Privileged daemon

Insecure Mode belongs to the system daemon rather than the desktop user. The
daemon stores it as `insecure_mode_enabled` in
`/var/lib/sing-box-daemon/settings.json`. The same file also contains the
locale last synchronized by the desktop application.

When `settings.core.insecureMode` is a boolean, the NixOS service invokes the
daemon's privileged `service set-insecure-mode` command before every start.
That command updates only the security field and preserves the locale. A null
option leaves the file untouched.

## Declarative reconciliation

Every nullable Nix option defaults to `null`, meaning the existing user value
is left alone. Explicit values are serialized to a generated configuration in
the Nix store and reconciled into `settings.db` when the primary desktop
process starts. `language = "auto"` and `theme = "default"` declaratively
remove their preference keys, matching the application's own representation of
those defaults.

If `profiles` is `null`, all existing profiles remain user-managed. If it is a
list (including an empty list), that list is authoritative on every launch:
metadata and JSON files not present in the list are removed. Profile IDs are
stable SHA-256 hashes of their names, and `defaultProfile` refers to a profile
by name.

Changes made through the UI after startup remain effective until the next
application launch, when explicitly managed values are applied again.

Nix store paths are readable by local users. Declarative profile JSON and
custom terminal themes must therefore not contain secrets. Keep credentials in
runtime-managed configuration or a separate secret-management mechanism.
