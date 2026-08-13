#!/usr/bin/env bash

# Print the configured worktree presentation mode. Native workspace mode is the
# default; set open_mode = "tab" to keep the original tab-based behavior.
worktrunk_config_value() {
  local key=$1 config_file

  if [[ -z ${HERDR_PLUGIN_CONFIG_DIR:-} ]]; then
    return
  fi

  config_file="$HERDR_PLUGIN_CONFIG_DIR/config.toml"
  if [[ ! -f $config_file ]]; then
    return
  fi

  # Accept both quoted strings (open_mode = "tab") and bare TOML scalars
  # (show_remote_branches = false); \2 is the quoted body, \3 the unquoted token.
  sed -nE \
    "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*(\"([^\"]*)\"|([^[:space:]#\"]+))[[:space:]]*(#.*)?$/\\2\\3/p" \
    "$config_file" | tail -n1
}

# Print "true"/"false" for whether the picker lists remote-tracking branches
# (origin/foo). Disabled by default; set show_remote_branches = true to show them.
worktrunk_show_remote_branches() {
  local value

  value=$(worktrunk_config_value show_remote_branches)

  case "$value" in
    ""|false)
      printf '%s\n' false
      ;;
    true)
      printf '%s\n' true
      ;;
    *)
      printf '\033[33mWarning:\033[0m unsupported show_remote_branches %q; hiding remote branches\n' "$value" >&2
      printf '%s\n' false
      ;;
  esac
}

worktrunk_open_mode() {
  local mode

  mode=$(worktrunk_config_value open_mode)

  case "$mode" in
    ""|workspace)
      printf '%s\n' workspace
      ;;
    tab)
      printf '%s\n' tab
      ;;
    *)
      printf '\033[33mWarning:\033[0m unsupported open_mode %q; using workspace\n' "$mode" >&2
      printf '%s\n' workspace
      ;;
  esac
}

# Print the optional layout plugin applied after Herdr opens a brand-new native
# worktree workspace. Existing workspaces and tab mode are never affected.
worktrunk_workspace_layout() {
  local plugin

  plugin=$(worktrunk_config_value workspace_layout)

  case "$plugin" in
    ""|none)
      printf '%s\n' none
      ;;
    herdr-spreader)
      printf '%s\n' herdr-spreader
      ;;
    *)
      printf '\033[33mWarning:\033[0m unsupported workspace_layout %q; using none\n' "$plugin" >&2
      printf '%s\n' none
      ;;
  esac
}

# Print "true" when a new worktree may inherit direnv trust from the source
# checkout for an identical .envrc file. Disabled by default.
worktrunk_auto_direnv_allow() {
  local value

  value=$(worktrunk_config_value auto_direnv_allow)

  case "$value" in
    ""|false)
      printf '%s\n' false
      ;;
    true)
      printf '%s\n' true
      ;;
    *)
      printf '\033[33mWarning:\033[0m unsupported auto_direnv_allow %q; using false\n' "$value" >&2
      printf '%s\n' false
      ;;
  esac
}

# Print "true" when pnpm dependencies should be installed before a brand-new
# native worktree workspace receives its configured layout. Disabled by default.
worktrunk_auto_pnpm_install() {
  local value

  value=$(worktrunk_config_value auto_pnpm_install)

  case "$value" in
    ""|false)
      printf '%s\n' false
      ;;
    true)
      printf '%s\n' true
      ;;
    *)
      printf \
        '\033[33mWarning:\033[0m unsupported auto_pnpm_install %q; using false\n' \
        "$value" >&2
      printf '%s\n' false
      ;;
  esac
}

# Print the workspace-label strategy. The customized plugin defaults to a
# compact, human-readable label while retaining the upstream branch-name
# behavior as an explicit option.
worktrunk_label_mode() {
  local mode

  mode=$(worktrunk_config_value label_mode)

  case "$mode" in
    ""|compact)
      printf '%s\n' compact
      ;;
    branch|ticket)
      printf '%s\n' "$mode"
      ;;
    *)
      printf '\033[33mWarning:\033[0m unsupported label_mode %q; using compact\n' "$mode" >&2
      printf '%s\n' compact
      ;;
  esac
}

# Print the maximum compact-label length. A value from 12 through 120 keeps the
# result useful while preventing accidental sidebar-filling labels.
worktrunk_label_max_length() {
  local value

  value=$(worktrunk_config_value label_max_length)

  if [[ -z $value ]]; then
    printf '%s\n' 32
    return
  fi

  if [[ $value =~ ^[0-9]+$ ]] && (( 10#$value >= 12 && 10#$value <= 120 )); then
    printf '%s\n' "$((10#$value))"
    return
  fi

  printf '\033[33mWarning:\033[0m unsupported label_max_length %q; using 32\n' "$value" >&2
  printf '%s\n' 32
}
