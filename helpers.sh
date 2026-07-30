#!/usr/bin/env bash

# True when NAME is a token worktrunk resolves itself — a branch shortcut
# (^ default, - previous) or `:` syntax (pr:N, mr:N, or a PR/MR URL). Git branch
# names can't be these bare symbols or contain `:`, so these must be passed to
# `wt switch` as-is, never with --create. `@` (current) is omitted: switching to
# the current worktree is a no-op, and its only real use is as a --base.
worktrunk_is_shortcut() {
  case $1 in
    '^'|'-'|*:*) return 0 ;;
    *) return 1 ;;
  esac
}

# True when NAME is an existing local branch or remote-tracking branch. Such refs
# are checked out directly by `wt switch NAME` (worktrunk creates the worktree if
# one doesn't exist yet), so they must never be passed with --create.
worktrunk_ref_exists() {
  git show-ref --quiet --verify "refs/heads/$1" \
    || git show-ref --quiet --verify "refs/remotes/$1"
}

# Convert a Git branch name into a readable Herdr workspace label.
#
# Modes:
#   branch  Preserve the full branch name (upstream behavior).
#   ticket  Use a leading issue key such as TASK-618, falling back to compact.
#   compact Preserve a leading issue key, normalize slug separators, and
#           truncate at a word boundary when possible.
worktrunk_format_label() {
  local name=$1
  local mode=${2:-compact}
  local max_length=${3:-32}
  local ticket=""
  local namespace=""
  local description=""
  local label=""
  local cutoff=""
  local candidate=""

  if [[ $mode == branch ]]; then
    printf '%s\n' "$name"
    return
  fi

  if [[ $name =~ ^([[:alpha:]][[:alnum:]]*-[[:digit:]]+)([/_-]+)?(.*)$ ]]; then
    ticket=${BASH_REMATCH[1]}
    description=${BASH_REMATCH[3]}
  elif [[ $name == */* ]]; then
    namespace=${name%%/*}
    description=${name#*/}
  else
    description=$name
  fi

  if [[ $mode == ticket && -n $ticket ]]; then
    printf '%s\n' "$ticket"
    return
  fi

  description=${description//\// }
  description=${description//-/ }
  description=${description//_/ }
  while [[ $description == *"  "* ]]; do
    description=${description//  / }
  done
  description=${description# }
  description=${description% }

  if [[ -n $ticket && -n $description ]]; then
    label="$ticket · $description"
  elif [[ -n $ticket ]]; then
    label=$ticket
  elif [[ -n $namespace && -n $description ]]; then
    label="$namespace · $description"
  elif [[ -n $namespace ]]; then
    label=$namespace
  else
    label=$description
  fi

  if (( ${#label} > max_length )); then
    cutoff=$((max_length - 1))
    candidate=${label:0:$cutoff}
    if [[ $candidate == *" "* ]]; then
      candidate=${candidate% *}
    fi
    label="${candidate}…"
  fi

  printf '%s\n' "$label"
}
