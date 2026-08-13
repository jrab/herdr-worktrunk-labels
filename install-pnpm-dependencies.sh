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

if ! command -v pnpm >/dev/null 2>&1; then
  printf '\033[33mWarning:\033[0m pnpm-lock.yaml exists, but pnpm is unavailable; skipping dependency install\n' >&2
  exit 0
fi

printf '\n\033[1mInstalling pnpm dependencies in %s\033[0m\n' "$worktree"
(cd "$worktree" && pnpm install)
