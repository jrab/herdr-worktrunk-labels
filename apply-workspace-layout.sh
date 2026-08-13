#!/usr/bin/env bash
set -euo pipefail

plugin_root=${HERDR_PLUGIN_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}
# shellcheck source=./config.sh
source "$plugin_root/config.sh"

layout_plugin=$(worktrunk_workspace_layout)
[[ $layout_plugin != none ]] || exit 0

open_result=$(cat)
already_open=$(jq -r '.result.already_open // false' <<<"$open_result")
[[ $already_open == false ]] || exit 0

workspace_id=$(jq -r '.result.workspace.workspace_id // empty' <<<"$open_result")
tab_id=$(jq -r '.result.tab.tab_id // empty' <<<"$open_result")
root_pane_id=$(jq -r '.result.root_pane.pane_id // empty' <<<"$open_result")
worktree_path=$(jq -r \
  '.result.workspace.worktree.checkout_path // .result.worktree.path // empty' \
  <<<"$open_result")
if [[ -z $workspace_id || -z $tab_id || -z $root_pane_id || -z $worktree_path ]]; then
  printf 'worktree open returned no target workspace, tab, root pane, or checkout path\n' >&2
  exit 1
fi
if [[ $worktree_path != /* ]]; then
  printf 'worktree open returned a non-absolute checkout path: %s\n' "$worktree_path" >&2
  exit 1
fi

herdr=${HERDR_BIN_PATH:-herdr}
plugin_json=$("$herdr" plugin list --plugin "$layout_plugin" --json)
layout_root=$(jq -r '.result.plugins[0].plugin_root // empty' <<<"$plugin_json")
layout_binary="$layout_root/target/release/herdr-spreader"
if [[ -z $layout_root || ! -x $layout_binary ]]; then
  printf 'configured workspace layout plugin is unavailable: %s\n' "$layout_plugin" >&2
  exit 1
fi

layout_config_dir=$("$herdr" plugin config-dir "$layout_plugin")
HERDR_PLUGIN_CONFIG_DIR=$layout_config_dir \
HERDR_BIN_PATH=$herdr \
  "$layout_binary" apply-existing \
    --workspace-id "$workspace_id" \
    --tab-id "$tab_id" \
    --root-pane-id "$root_pane_id" \
    --root "$worktree_path"
