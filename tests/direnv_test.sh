#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/bin" "$sandbox/config" "$sandbox/source" "$sandbox/worktree"
printf 'auto_direnv_allow = true\n' > "$sandbox/config/config.toml"
printf 'use flake\n' > "$sandbox/source/.envrc"
cp "$sandbox/source/.envrc" "$sandbox/worktree/.envrc"

cat > "$sandbox/bin/direnv" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  status)
    printf '{"state":{"foundRC":{"path":"%s/.envrc","allowed":%s}}}\n' \
      "$PWD" "${FAKE_SOURCE_ALLOWED:-0}"
    ;;
  allow)
    printf '%s\n' "$2" >> "$FAKE_DIRENV_LOG"
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$sandbox/bin/direnv"

export PATH="$sandbox/bin:$PATH"
export HERDR_PLUGIN_CONFIG_DIR="$sandbox/config"
export FAKE_DIRENV_LOG="$sandbox/allow.log"

"$repo_root/allow-direnv.sh" "$sandbox/source" "$sandbox/worktree"
grep -Fxq "$sandbox/worktree/.envrc" "$FAKE_DIRENV_LOG"

: > "$FAKE_DIRENV_LOG"
printf 'changed\n' > "$sandbox/worktree/.envrc"
"$repo_root/allow-direnv.sh" "$sandbox/source" "$sandbox/worktree"
[[ ! -s $FAKE_DIRENV_LOG ]]

cp "$sandbox/source/.envrc" "$sandbox/worktree/.envrc"
export FAKE_SOURCE_ALLOWED=1
"$repo_root/allow-direnv.sh" "$sandbox/source" "$sandbox/worktree"
[[ ! -s $FAKE_DIRENV_LOG ]]

printf 'direnv tests passed\n'
