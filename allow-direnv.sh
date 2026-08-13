#!/usr/bin/env bash
set -euo pipefail

plugin_root=${HERDR_PLUGIN_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}
# shellcheck source=./config.sh
source "$plugin_root/config.sh"

[[ $(worktrunk_auto_direnv_allow) == true ]] || exit 0
command -v direnv >/dev/null 2>&1 || exit 0

source_checkout=${1:?source checkout path is required}
worktree=${2:?worktree path is required}
source_envrc="$source_checkout/.envrc"
worktree_envrc="$worktree/.envrc"

# Trust is inherited only from the exact already-allowed source file. A branch
# that adds or changes .envrc remains blocked for manual review.
[[ -f $source_envrc && -f $worktree_envrc ]] || exit 0
cmp -s "$source_envrc" "$worktree_envrc" || exit 0

source_status=$(cd "$source_checkout" && direnv status --json 2>/dev/null) || exit 0
source_found=$(jq -r '.state.foundRC.path // empty' <<<"$source_status")
source_allowed=$(jq -r '.state.foundRC.allowed // empty' <<<"$source_status")
[[ $source_found == "$source_envrc" && $source_allowed == 0 ]] || exit 0

direnv allow "$worktree_envrc"
