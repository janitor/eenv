# eenv (fish)

A fish shell plugin that manages environment variable sets through simple commands.

## Installation

```fish
fisher install janitor/eenv
```

## Commands

- `eenv create <name>` (alias: `new`) — creates an environment file at `~/.config/fish/eenv/envs/<name>.env`.
- `eenv activate <name>` (alias: `enable`) — activates an environment and removes variables from the previously active environment.
- `eenv deactivate` (alias: `disable`) — deactivates the current environment, removing all its variables.
- `eenv edit [name]` — opens `$EDITOR` to edit the specified environment, or the active one if no name is provided.
- `eenv list` (alias: `ls`) — shows available environments, marking the active one.
- `eenv describe [name]` (alias: `desc`) — shows all variables with their values from the specified environment, or the active one if no name is provided. Sensitive variables (containing "token", "key", "secret", or "pass" in the name) are automatically masked.
- `eenv --help` — shows brief help message.

The currently active environment is stored in `~/.config/fish/eenv/active` and is automatically restored in new sessions.

## Configuration

The following environment variables can be used to configure eenv:

- `EENV_ROOT` — sets the base storage path for eenv files (default: `~/.config/fish/eenv`). All eenv files (environments and active state) will be stored under this directory.

- `EENV_DISABLE_AUTOLOAD` — when set to `1`, disables automatic restoration of the active environment in new shell sessions. By default, eenv automatically restores the previously active environment when a new fish session starts.

Example:
```fish
set -gx EENV_ROOT ~/.local/share/eenv
set -gx EENV_DISABLE_AUTOLOAD 1
```

## Environment File Format

Files are simple `KEY=VALUE` pairs, lines starting with `#` are ignored. Values with spaces should be quoted. Example:

```
# Comment
FOO=bar
PATH=/custom/bin:$PATH
API_TOKEN="secret value"
```

Variables defined in a deactivated environment will be removed from the current session when another one is activated.

## Security

The `describe` command automatically masks sensitive values. Variables whose names contain "token", "key", "secret", or "pass" (case-insensitive) will have their values partially masked, showing only the first and last 2 characters with asterisks in between (e.g., `ab******cd`). Short values (6 characters or less) are completely masked as `***`.
