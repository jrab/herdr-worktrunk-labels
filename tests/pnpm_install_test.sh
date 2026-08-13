#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/bin" "$sandbox/config" "$sandbox/worktree"
printf 'auto_pnpm_install = true\n' > "$sandbox/config/config.toml"
printf 'lockfileVersion: 9.0\n' > "$sandbox/worktree/pnpm-lock.yaml"

cat > "$sandbox/bin/pnpm" <<'EOF'
#!/usr/bin/env bash
printf 'cwd=%s args=%s\n' "$PWD" "$*" >> "$FAKE_PNPM_LOG"
EOF
chmod +x "$sandbox/bin/pnpm"

export PATH="$sandbox/bin:$PATH"
export HERDR_PLUGIN_CONFIG_DIR="$sandbox/config"
export FAKE_PNPM_LOG="$sandbox/pnpm.log"

new_workspace='{"result":{"already_open":false}}'
"$repo_root/install-pnpm-dependencies.sh" "$sandbox/worktree" <<<"$new_workspace"
grep -Fxq "cwd=$sandbox/worktree args=install" "$FAKE_PNPM_LOG"

: > "$FAKE_PNPM_LOG"
existing_workspace='{"result":{"already_open":true}}'
"$repo_root/install-pnpm-dependencies.sh" "$sandbox/worktree" <<<"$existing_workspace"
[[ ! -s $FAKE_PNPM_LOG ]]

rm "$sandbox/worktree/pnpm-lock.yaml"
"$repo_root/install-pnpm-dependencies.sh" "$sandbox/worktree" <<<"$new_workspace"
[[ ! -s $FAKE_PNPM_LOG ]]

printf 'lockfileVersion: 9.0\n' > "$sandbox/worktree/pnpm-lock.yaml"
printf 'auto_pnpm_install = false\n' > "$sandbox/config/config.toml"
"$repo_root/install-pnpm-dependencies.sh" "$sandbox/worktree" <<<"$new_workspace"
[[ ! -s $FAKE_PNPM_LOG ]]

printf 'pnpm install tests passed\n'
