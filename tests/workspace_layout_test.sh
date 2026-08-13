#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

mkdir -p "$sandbox/config" "$sandbox/spreader/target/release"
printf 'workspace_layout = "herdr-spreader"\n' > "$sandbox/config/config.toml"

cat > "$sandbox/herdr" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  'plugin list --plugin herdr-spreader --json')
    printf '{"result":{"plugins":[{"plugin_root":"%s"}]}}\n' "$FAKE_SPREADER_ROOT"
    ;;
  'plugin config-dir herdr-spreader')
    printf '%s\n' "$FAKE_SPREADER_CONFIG"
    ;;
  *)
    printf 'unexpected fake herdr arguments: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$sandbox/herdr"

cat > "$sandbox/spreader/target/release/herdr-spreader" <<'EOF'
#!/usr/bin/env bash
printf 'config=%s\n' "$HERDR_PLUGIN_CONFIG_DIR" >> "$FAKE_SPREADER_LOG"
printf '%s\n' "$*" >> "$FAKE_SPREADER_LOG"
EOF
chmod +x "$sandbox/spreader/target/release/herdr-spreader"

export HERDR_PLUGIN_CONFIG_DIR="$sandbox/config"
export HERDR_BIN_PATH="$sandbox/herdr"
export FAKE_SPREADER_ROOT="$sandbox/spreader"
export FAKE_SPREADER_CONFIG="$sandbox/spreader-config"
export FAKE_SPREADER_LOG="$sandbox/spreader.log"

new_workspace='{"result":{"already_open":false,"workspace":{"workspace_id":"w2","worktree":{"checkout_path":"/worktrees/topic"}},"tab":{"tab_id":"w2:t1"},"root_pane":{"pane_id":"w2:p1","cwd":"/transient/.oh-my-zsh"},"worktree":{"path":"/worktrees/topic"}}}'
"$repo_root/apply-workspace-layout.sh" <<<"$new_workspace"

grep -Fxq "config=$FAKE_SPREADER_CONFIG" "$FAKE_SPREADER_LOG"
grep -Fxq \
  'apply-existing --workspace-id w2 --tab-id w2:t1 --root-pane-id w2:p1 --root /worktrees/topic' \
  "$FAKE_SPREADER_LOG"

before=$(wc -l < "$FAKE_SPREADER_LOG")
existing_workspace='{"result":{"already_open":true,"workspace":{"workspace_id":"w2"},"tab":{"tab_id":"w2:t1"},"root_pane":{"pane_id":"w2:p1"}}}'
"$repo_root/apply-workspace-layout.sh" <<<"$existing_workspace"
after=$(wc -l < "$FAKE_SPREADER_LOG")
[[ $before == "$after" ]]

missing_path='{"result":{"already_open":false,"workspace":{"workspace_id":"w3"},"tab":{"tab_id":"w3:t1"},"root_pane":{"pane_id":"w3:p1"}}}'
if "$repo_root/apply-workspace-layout.sh" <<<"$missing_path" 2>"$sandbox/missing-path.log"; then
  printf 'expected layout handoff without a checkout path to fail\n' >&2
  exit 1
fi
grep -Fq 'checkout path' "$sandbox/missing-path.log"

printf 'workspace layout tests passed\n'
