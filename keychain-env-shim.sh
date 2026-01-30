# shellcheck disable=SC2148,SC2296
# SC2148: file is sourced by zsh, not executed (no shebang).
# SC2296: zsh parameter expansion (e.g. ${(s/:/)_var}, ${(P)key}) is valid when sourced by zsh.
# Source this from ~/.zshrc so Keychain placeholders in any .env are resolved into the shell.
# Usage in ~/.zshrc:  source "$HOME/.local/bin/keychain-env-shim.sh"
#
# By default the shim does NOT resolve in any directory. Run `keychain-env-trust` in a
# project directory to add it to trusted roots; the shim will then resolve there.
# Trusted roots are stored in ~/.config/pk-keychain-management/trusted_roots (one path per line).
# You can also set KEYCHAIN_ENV_TRUSTED_ROOTS (colon-separated) to override/extend.
#
# Store your dev private key in Keychain once. The item name MUST contain "PRIVATE_KEY"
# or "PKEY" (e.g. ETH_DEV_PRIVATE_KEY, MY_PKEY):
#   security add-generic-password -U -s "ETH_DEV_PRIVATE_KEY" -a "you" -w "0x...."
#
# In any EVM project .env: PRIVATE_KEY=ETH_DEV_PRIVATE_KEY (or keychain:ETH_DEV_PRIVATE_KEY).

KEYCHAIN_RESOLVED_VARS=()
typeset -g -A KEYCHAIN_SAVED_VARS
KEYCHAIN_ENV_TRUSTED_ROOTS_FILE="${KEYCHAIN_ENV_TRUSTED_ROOTS_FILE:-$HOME/.config/pk-keychain-management/trusted_roots}"

_resolve_keychain_refs_in_env() {
  local env_file="$PWD/.env"
  local keychain_item=""
  local secret=""
  local root=""
  local _under_trusted=0
  local _trusted_roots="${KEYCHAIN_ENV_TRUSTED_ROOTS:-}"
  local canon_pwd
  canon_pwd=$(cd -P . 2>/dev/null && pwd) || canon_pwd="$PWD"

  # Load trusted roots from file if not set (one path per line -> colon-separated)
  if [[ -z "$_trusted_roots" ]] && [[ -f "$KEYCHAIN_ENV_TRUSTED_ROOTS_FILE" ]]; then
    _trusted_roots=$(tr '\n' ':' < "$KEYCHAIN_ENV_TRUSTED_ROOTS_FILE" | sed 's/:$//')
  fi

  # Path boundary: trusted only if canon_pwd equals root or is under root/ (avoids /Users/me/dev matching /Users/me/devil-project)
  if [[ -n "$_trusted_roots" ]]; then
    for root in ${(s/:/)_trusted_roots}; do
      root="${root%/}"
      [[ -z "$root" ]] && continue
      if [[ "$canon_pwd" == "$root" || "$canon_pwd" == "$root"/* ]]; then
        _under_trusted=1
        break
      fi
    done
  fi

  # Restore previously resolved vars to their prior values (or unset)
  if [[ ${#KEYCHAIN_RESOLVED_VARS[@]} -gt 0 ]]; then
    for v in "${KEYCHAIN_RESOLVED_VARS[@]}"; do
      if [[ "${KEYCHAIN_SAVED_VARS[$v]:-}" == "__KEYCHAIN_UNSET__" ]]; then
        unset -v "$v" 2>/dev/null || true
      else
        export "$v=${KEYCHAIN_SAVED_VARS[$v]}"
      fi
      unset "KEYCHAIN_SAVED_VARS[$v]"
    done
    KEYCHAIN_RESOLVED_VARS=()
  fi

  [[ $_under_trusted -eq 0 ]] && return 0
  [[ ! -f "$env_file" ]] && return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "$line" != *"="* ]] && continue

    local key="${line%%=*}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    local val="${line#*=}"
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%"${val##*[![:space:]]}"}"
    val="${val%\"}"
    val="${val#\"}"
    val="${val%\'}"
    val="${val#\'}"
    val="${val%%#*}"
    val="${val%"${val##*[![:space:]]}"}"

    if [[ -z "$key" || -z "$val" ]]; then
      continue
    fi

    [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && continue

    if [[ "$val" == keychain:* ]]; then
      keychain_item="${val#keychain:}"
    elif [[ "$val" =~ ^[A-Za-z0-9_]+$ ]]; then
      keychain_item="$val"
    else
      continue
    fi

    local upper
    upper=$(echo "$keychain_item" | tr '[:lower:]' '[:upper:]')
    if [[ "$upper" != *"PRIVATE_KEY"* && "$upper" != *"PKEY"* ]]; then
      if [[ "$val" == keychain:* ]]; then
        echo "keychain-env-shim: Keychain ref refused (allowlist): $key=$val (item name must contain PRIVATE_KEY or PKEY)" >&2
      fi
      continue
    fi

    secret=$(security find-generic-password -s "$keychain_item" -w 2>/dev/null) || true
    if [[ -z "$secret" ]]; then
      if [[ "$val" == keychain:* ]]; then
        echo "keychain-env-shim: Keychain item not found or empty: $keychain_item (for $key=$val)" >&2
      fi
      continue
    fi

    [[ -z "${KEYCHAIN_SAVED_VARS[$key]+set}" ]] && KEYCHAIN_SAVED_VARS[$key]="${(P)key:-__KEYCHAIN_UNSET__}"

    export "$key=$secret"
    KEYCHAIN_RESOLVED_VARS+=("$key")
  done < "$env_file"

  return 0
}

# Register chpwd hook only once (avoid duplicate registration if sourced multiple times)
if [[ -z "${_KEYCHAIN_ENV_SHIM_LOADED:-}" ]]; then
  _KEYCHAIN_ENV_SHIM_LOADED=1
  chpwd_functions+=(_resolve_keychain_refs_in_env)
fi
_resolve_keychain_refs_in_env
