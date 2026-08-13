#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/bin" "$sandbox/config" "$sandbox/worktree"
printf 'auto_pnpm_install = true\n' > "$sandbox/config/config.toml"
printf 'lockfileVersion: 9.0\n' > "$sandbox/worktree/pnpm-lock.yaml"

cat > "$sandbox/bin/herdr" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_HERDR_LOG"
EOF
chmod +x "$sandbox/bin/herdr"

export HERDR_PLUGIN_CONFIG_DIR="$sandbox/config"
export HERDR_BIN_PATH="$sandbox/bin/herdr"
export FAKE_HERDR_LOG="$sandbox/herdr.log"

new_workspace='{"result":{"already_open":false,"root_pane":{"pane_id":"w2:p1"}}}'
"$repo_root/install-pnpm-dependencies.sh" "$sandbox/worktree" <<<"$new_workspace"
grep -Fxq 'pane run w2:p1 pnpm install' "$FAKE_HERDR_LOG"

: > "$FAKE_HERDR_LOG"
existing_workspace='{"result":{"already_open":true}}'
"$repo_root/install-pnpm-dependencies.sh" "$sandbox/worktree" <<<"$existing_workspace"
[[ ! -s $FAKE_HERDR_LOG ]]

rm "$sandbox/worktree/pnpm-lock.yaml"
"$repo_root/install-pnpm-dependencies.sh" "$sandbox/worktree" <<<"$new_workspace"
[[ ! -s $FAKE_HERDR_LOG ]]

printf 'lockfileVersion: 9.0\n' > "$sandbox/worktree/pnpm-lock.yaml"
printf 'auto_pnpm_install = false\n' > "$sandbox/config/config.toml"
"$repo_root/install-pnpm-dependencies.sh" "$sandbox/worktree" <<<"$new_workspace"
[[ ! -s $FAKE_HERDR_LOG ]]

printf 'auto_pnpm_install = true\n' > "$sandbox/config/config.toml"
missing_root='{"result":{"already_open":false}}'
if "$repo_root/install-pnpm-dependencies.sh" "$sandbox/worktree" \
  <<<"$missing_root" 2>"$sandbox/missing-root.log"; then
  printf 'expected pnpm install without a root pane to fail\n' >&2
  exit 1
fi
grep -Fq 'no root pane' "$sandbox/missing-root.log"

printf 'pnpm install tests passed\n'
