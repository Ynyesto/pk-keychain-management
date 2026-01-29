# Source this from ~/.zshrc so Keychain placeholders in any .env are resolved into the shell.
# Usage in ~/.zshrc:  source "$HOME/.local/bin/keychain-env-shim.sh"
#
# Store your dev private key in Keychain once, e.g.:
#   security add-generic-password -U -s "ETH_DEV_PRIVATE_KEY" -a "you" -w "0x...."
#
# In any EVM project .env, use whichever variable name that project expects, with the
# Keychain item name as the value (so it behaves like the plaintext key was there):
#
#   PKEY=ETH_DEV_PRIVATE_KEY
#   PRIVATE_KEY=ETH_DEV_PRIVATE_KEY
#   SECRET_KEY=ETH_DEV_PRIVATE_KEY
#   ETH_SEPOLIA_KEY=ETH_DEV_PRIVATE_KEY
#   # or explicitly:   SOME_VAR=keychain:ETH_DEV_PRIVATE_KEY
#
# When you cd into that project, we resolve each such line from Keychain and export
# the same variable name with the secret — so any tool (hardhat, forge, etc.) sees it.

KEYCHAIN_RESOLVED_VARS=()

_resolve_keychain_refs_in_env() {
  local dir="$PWD"
  local env_file=""
  local keychain_item=""
  local secret=""

  # Clear any vars we previously resolved (so we don't leak when leaving a project)
  if [[ ${#KEYCHAIN_RESOLVED_VARS[@]} -gt 0 ]]; then
    for v in "${KEYCHAIN_RESOLVED_VARS[@]}"; do
      unset -v "$v" 2>/dev/null || true
    done
    KEYCHAIN_RESOLVED_VARS=()
  fi

  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -f "$dir/.env" ]]; then
      env_file="$dir/.env"
      break
    fi
    dir="${dir%/*}"
  done

  if [[ -z "$env_file" ]]; then
    return 0
  fi

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

    # Value is keychain:ITEM_NAME or bare Keychain item name (single-word identifier)
    if [[ "$val" == keychain:* ]]; then
      keychain_item="${val#keychain:}"
    elif [[ "$val" =~ ^[A-Za-z0-9_]+$ ]]; then
      keychain_item="$val"
    else
      continue
    fi

    secret=$(security find-generic-password -s "$keychain_item" -w 2>/dev/null) || true
    if [[ -z "$secret" ]]; then
      continue
    fi

    export "$key=$secret"
    KEYCHAIN_RESOLVED_VARS+=("$key")
  done < "$env_file"

  return 0
}

chpwd_functions+=(_resolve_keychain_refs_in_env)
_resolve_keychain_refs_in_env
