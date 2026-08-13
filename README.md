# Worktrunk Labels

This fork extends the Worktrunk Herdr plugin with readable workspace labels
derived from branch names while preserving the upstream worktree workflow.

## Readable workspace labels

The default `compact` mode keeps a leading issue key, converts slug separators
to spaces, and truncates long labels at a word boundary:

```text
TASK-618/standardize-data-grids-and-migrate-to-new-table
→ TASK-618 · standardize data…
```

Configure the behavior in the plugin's managed configuration directory:

```bash
config_dir=$(herdr plugin config-dir worktrunk-labels)
mkdir -p "$config_dir"
${EDITOR:-vi} "$config_dir/config.toml"
```

```toml
# "compact" (default), "ticket", or "branch"
label_mode = "compact"

# Used by compact mode; accepted range is 12–120.
label_max_length = 32
```

- `compact` produces a readable, bounded label.
- `ticket` uses only a leading issue key such as `TASK-618`; branches without
  an issue key fall back to the compact representation.
- `branch` preserves the complete Git branch name, matching upstream behavior.

These options affect only the Herdr workspace or tab label. Git branch names and
worktree paths remain unchanged. Configuration is read every time the picker
runs, so changes apply without reinstalling or reloading the plugin.

A [herdr](https://herdr.dev) plugin for switching, creating, and removing git
worktrees through [worktrunk](https://github.com/max-sixty/worktrunk). Pick (or
type) a branch in an fzf picker and open the worktree as a herdr tab or a native
worktree workspace — with worktrunk's hooks running along the way.

## Why this plugin

herdr already ships with its own worktree management (`herdr worktree
create/open/remove/list`), and it works fine. But worktrunk is a dedicated
worktree manager that does more — most importantly, **lifecycle hooks**: run
setup when a worktree is created (install deps, copy `.env` files, bootstrap
services) and teardown when it's removed, with template variables like
`{{ branch }}` and `{{ worktree_path }}`. herdr's built-in worktree commands
have no hook system.

Rather than reimplement hooks inside herdr, this plugin wires worktrunk's `wt`
into herdr: you get worktrunk's hook-driven workflow (plus its niceties — base
branch selection, PR shortcuts, live preview) while choosing whether the
resulting worktree opens as a tab or as a native linked-worktree workspace.

## What it does

Three workspace actions:

- **Worktree: switch / create from default branch** — opens an fzf picker over
  your existing worktrees and local branches without worktrees (remote-tracking
  branches too, if enabled — see [Remote branches in the picker](#remote-branches-in-the-picker)).
  Press `Enter` on a match to switch to it, or type a new name and press `Enter`
  to create it from worktrunk's default base branch.

- **Worktree: switch / create from current branch** — the same picker, but typed
  new branch names are created with `wt switch --create --base @`, i.e. from the
  currently checked-out branch/worktree.

Both create actions support [worktrunk syntax for PR/MR along with other shortcuts](https://worktrunk.dev/switch/#shortcuts).
Worktrunk's lifecycle hooks run in either presentation mode, and the checkout
opens as a tab or a native worktree workspace according to plugin configuration.

- **Worktree: remove** — opens an fzf picker over removable worktrees
  (everything except the main checkout). Pick one; worktrunk prompts for
  confirmation and gates unmerged branches / untracked files itself, then
  removes it. The native workspace or any legacy tab panes associated with the
  deleted worktree are closed automatically.

## Worktree presentation

By default the plugin organizes worktrees the same way as herdr's built-in
worktree support: each checkout becomes a nested worktree workspace in the
sidebar. To restore the original tab-based behavior, set `open_mode` to `"tab"`
in the plugin's managed configuration directory:

```bash
config_dir=$(herdr plugin config-dir worktrunk-labels)
mkdir -p "$config_dir"
${EDITOR:-vi} "$config_dir/config.toml"
```

```toml
open_mode = "tab"
```

Supported values:

- `open_mode = "workspace"` — let Worktrunk create or switch the checkout and
  run its hooks, then register that checkout with `herdr worktree open`. Herdr
  displays it as a nested worktree workspace in the sidebar. This is the default.
- `open_mode = "tab"` — open a new tab in the current workspace and run `wt`
  there. This preserves the original plugin behavior.

The config file is read each time the picker runs, so changing the mode does
not require reinstalling or reloading the plugin.

### New-workspace layout

Native worktree workspaces can opt into a layout supplied by the managed
`herdr-spreader` fork:

```toml
workspace_layout = "herdr-spreader"
```

After `worktree open` creates a workspace, Worktrunk passes the returned
workspace, first-tab, root-pane IDs, and authoritative checkout path to
Spreader. Passing the checkout path prevents shell startup hooks from
temporarily redirecting new split panes into a directory such as
`~/.oh-my-zsh`. Spreader applies its
single configured workspace to those existing objects instead of creating a
duplicate workspace. Reopening an already-open worktree does not apply the
layout again. The setting defaults to `"none"`.

### Inheriting direnv trust

Set `auto_direnv_allow = true` to let a new worktree inherit direnv trust from
the source checkout. The plugin runs `direnv allow` only when both checkouts
contain byte-identical root `.envrc` files and direnv reports that the source
file is already allowed. A branch that adds or modifies `.envrc` remains
blocked for manual review. The setting defaults to `false`.

## Remote branches in the picker

By default the picker lists only your worktrees and local branches. To also
offer remote-tracking branches (e.g. `origin/foo`; run `git fetch` yourself to
refresh these), set `show_remote_branches` to `true` in the same `config.toml`:

```toml
show_remote_branches = true
```

Local branches without worktrees always appear regardless of this setting.

## Requirements

- [**herdr**](https://herdr.dev) ≥ 0.7.0
- [**worktrunk**](https://github.com/max-sixty/worktrunk) ≥ 0.60.0 — the `wt` CLI on your `PATH`
- **fzf** — the interactive picker
- **jq** — JSON parsing
- **bash** — the scripts run with `/bin/bash`

Platforms: macOS and Linux.

## Installation

Clone the upstream plugin, apply the custom-label changes, then link the local
checkout:

```bash
herdr plugin link /path/to/herdr-worktrunk-labels
```

## Usage

### Create/Switch a worktree from the default branch
```
herdr plugin action invoke open --plugin worktrunk-labels
```

### Create/Switch a worktree from the current branch
```
herdr plugin action invoke open-current --plugin worktrunk-labels
```

### Remove Worktree
```
herdr plugin action invoke remove --plugin worktrunk-labels
```

## Keybindings

To drive the plugin from the keyboard, add `[[keys.command]]` entries to
`~/.config/herdr/config.toml` with `type = "plugin_action"`. The `command` is the
plugin's action id qualified with the plugin id (`worktrunk-labels.<action>`;
run
`herdr plugin action list` to see the ids):

```toml
# Override herdr's built-in "new worktree" key (prefix+shift+g) with worktrunk's
# default-branch switch/create picker:
[[keys.command]]
key = "prefix+shift+g"
type = "plugin_action"
command = "worktrunk-labels.open"
description = "Worktree: switch / create from default branch"

# Optional: bind current-branch creation separately.
[[keys.command]]
key = "prefix+shift+c"
type = "plugin_action"
command = "worktrunk-labels.open-current"
description = "Worktree: switch / create from current branch"

[[keys.command]]
key = "prefix+shift+d"
type = "plugin_action"
command = "worktrunk-labels.remove"
description = "Worktree: remove"
```

**Recommended:** override herdr's built-in worktree management with these. herdr
binds `prefix+shift+g` to "new worktree" by default, and a custom keybinding takes
precedence over the built-in on the same key — so mapping
`worktrunk-labels.open`
to `prefix+shift+g` replaces it with worktrunk's switch/create picker, hooks
included. Pick matching keys for `worktrunk-labels.open-current` and
`worktrunk-labels.remove` to round out the workflow.

Reload the config after editing it:

```bash
herdr server reload-config
```

## Development

The plugin is a manifest plus small bash scripts:

- `herdr-plugin.toml` — actions and panes
- `config.sh` — worktree presentation configuration
- `helpers.sh` — shared shell helpers (e.g. worktrunk shortcut detection)
- `picker.sh` — the switch / create picker
- `remove.sh` — the remove picker + orphaned-pane cleanup
- `tests/config_test.sh` — configuration parser checks
- `tests/helpers_test.sh` — helper function checks

herdr caches the manifest when a plugin is linked, so after editing
`herdr-plugin.toml` you must relink for changes to take effect:

```bash
herdr plugin unlink worktrunk-labels
herdr plugin link "$PWD"
```

Edits to the bash scripts are picked up on the next run — no relink needed.

## License

[MIT](LICENSE.md) © Devashish Chandra
