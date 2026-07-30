#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../helpers.sh
source "$repo_root/helpers.sh"

for tok in '^' '-' 'pr:123' 'mr:45' 'https://github.com/o/r/pull/7'; do
  if ! worktrunk_is_shortcut "$tok"; then
    printf 'expected %q to be a worktrunk shortcut\n' "$tok" >&2
    exit 1
  fi
done

# @ (current) is intentionally not a shortcut — see helpers.sh.
for tok in 'my-feature' 'main' 'feature/foo' '@'; do
  if worktrunk_is_shortcut "$tok"; then
    printf 'expected %q not to be a worktrunk shortcut\n' "$tok" >&2
    exit 1
  fi
done

# worktrunk_ref_exists resolves both local heads and remote-tracking branches.
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
(
  cd "$sandbox"
  git init -q
  git config user.email test@example.com
  git config user.name test
  git commit -q --allow-empty -m init
  git branch feature
  git update-ref refs/remotes/origin/remote-feat HEAD
)
cd "$sandbox"

for ref in 'feature' 'origin/remote-feat'; do
  if ! worktrunk_ref_exists "$ref"; then
    printf 'expected %q to be an existing ref\n' "$ref" >&2
    exit 1
  fi
done

for ref in 'does-not-exist' 'origin/nope'; do
  if worktrunk_ref_exists "$ref"; then
    printf 'expected %q not to be an existing ref\n' "$ref" >&2
    exit 1
  fi
done

cd - >/dev/null

assert_label() {
  local expected=$1 name=$2 mode=${3:-compact} max_length=${4:-32} actual
  actual=$(worktrunk_format_label "$name" "$mode" "$max_length")
  if [[ $actual != "$expected" ]]; then
    printf 'expected label %q, got %q\n' "$expected" "$actual" >&2
    exit 1
  fi
}

assert_label \
  'TASK-618 · standardize data…' \
  'TASK-618/standardize-data-grids-and-migrate-to-new-table'
assert_label 'TASK-618' 'TASK-618/standardize-data-grids' ticket
assert_label \
  'TASK-618/standardize-data-grids' \
  'TASK-618/standardize-data-grids' \
  branch
assert_label 'breadcrumbs missing' 'breadcrumbs-missing'
assert_label 'feature · concise name' 'feature/concise-name'
assert_label 'averyverylo…' 'averyverylongunbrokenname' compact 12

printf 'helpers tests passed\n'
