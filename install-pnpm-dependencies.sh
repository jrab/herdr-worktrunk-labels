#!/usr/bin/env bash
set -euo pipefail

plugin_root=${HERDR_PLUGIN_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}
# shellcheck source=./config.sh
source "$plugin_root/config.sh"

[[ $(worktrunk_auto_pnpm_install) == true ]] || exit 0

worktree=${1:?worktree path is required}
open_result=$(cat)
already_open=$(jq -r '.result.already_open // false' <<<"$open_result")
[[ $already_open == false ]] || exit 0

# A lockfile opts the checkout into pnpm and prevents this generic integration
# from guessing the package manager for npm, Yarn, or Bun repositories.
[[ -f $worktree/pnpm-lock.yaml ]] || exit 0

root_pane_id=$(jq -r '.result.root_pane.pane_id // empty' <<<"$open_result")
if [[ -z $root_pane_id ]]; then
  printf 'worktree open returned no root pane for pnpm install\n' >&2
  exit 1
fi

herdr=${HERDR_BIN_PATH:-herdr}
"$herdr" pane run "$root_pane_id" "pnpm install"
