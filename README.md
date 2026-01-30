# Private Key MacOS Keychain Management

Use your Ethereum (or other EVM) private key from `.env` **without storing it in plaintext**. Works with Hardhat, Foundry, or any tool that reads a private key from an env var. One Keychain item, two scripts. No external services required.

- Store the key **once** in macOS Keychain.
- In project `.env`, put only the **name** of that item (e.g. `PRIVATE_KEY=ETH_DEV_PRIVATE_KEY`).
- Your tool sees the real key in the environment; the key never sits in a file.

**Disclaimer:** This setup is for **dev keys only**—low-value, local use. Do not use it for production keys or keys holding real funds. For those, use proper tooling (e.g. Foundry’s encrypted keystore, Hardhat’s wallet/keystore options) and/or cold wallets, not env-based key loading.

---

## Install

1. **Scripts on PATH** (e.g. `~/.local/bin`):

   ```bash
   cd /path/to/pk-keychain-management
   cp keychain-env-shim.sh keychain-env-trust with-keychain ~/.local/bin/
   chmod +x ~/.local/bin/keychain-env-trust ~/.local/bin/with-keychain
   ```

   The shim is **sourced** from `~/.zshrc`, not executed; only `keychain-env-trust` and `with-keychain` need to be executable. Ensure `~/.local/bin` is in your `PATH` (e.g. in `~/.zshrc`: `export PATH="$HOME/.local/bin:$PATH"`).

2. **Store your key in Keychain once.** Item name must contain `PRIVATE_KEY` or `PKEY` (e.g. `ETH_DEV_PRIVATE_KEY`) to avoid exposing other unrelated Keychain secrets:

   ```bash
   security add-generic-password -U -s "ETH_DEV_PRIVATE_KEY" -a "you" -w "0xYOUR_PRIVATE_KEY"
   ```

   Lookup uses the **service name** (`-s`) only—keep it unique. The account (`-a`) is for display in Keychain Access only. When macOS prompts, prefer **Allow** or **Allow Once**. Avoid **Always Allow**—it can significantly reduce friction for any process running as you to read the item.

3. **Optional — auto-resolve on `cd` (zsh):** In `~/.zshrc` add:

   ```bash
   source "$HOME/.local/bin/keychain-env-shim.sh"
   ```

   In a directory you trust, run once: `keychain-env-trust` — that adds the **current directory** as a trusted root (the shim will resolve in that directory and its subdirectories). Then run `cd .` or open a new terminal and `cd` to the project so the shim picks it up.

---

## Usage

**In the project `.env`:** use the variable name your tool expects, value = Keychain item name:

```bash
PRIVATE_KEY=ETH_DEV_PRIVATE_KEY
```

**Run your tool:**

- **With the shim:** After `keychain-env-trust` and `cd` into the project, run e.g. `npx hardhat run ...` or `forge script ...` — the key is already in the environment.
- **Without the shim:** `with-keychain -- npx hardhat run ...` or `with-keychain -- forge script ...`

---

## Scripts

| Script | Purpose |
|--------|--------|
| **keychain-env-shim.sh** | Zsh hook: on every `cd`, in trusted dirs only, loads `$PWD/.env` and resolves Keychain refs into env vars; restores/unsets when you leave. |
| **keychain-env-trust** | Add/remove/list trusted roots (`keychain-env-trust`, `--list`, `--remove`). Roots in `~/.config/pk-keychain-management/trusted_roots`. |
| **with-keychain** | One-off: `with-keychain -- <command>` — loads `.env`, resolves refs, runs command. Use when shim isn’t active or for untrusted repos. |

---

## Requirements

- macOS (uses `security` and Keychain).
- zsh for the shim; `with-keychain` is bash and works in any shell.
- **Not for CI or production keys** — dev / local use only.

---

## Reference

- **Allowlist:** Only item names containing `PRIVATE_KEY` or `PKEY` (case-insensitive) are resolved. Other Keychain items are never touched.
- **Trusted roots:** By default the shim resolves in **no** directory. Run `keychain-env-trust` in a project to add it. After adding, run `cd .` or open a new terminal so the shim picks it up.
- **Security:** The key ends up in env vars—any script in that shell can read it. Use a **dev-only key** with low funds. Prefer `with-keychain` for untrusted repos; avoid running `npm install` or arbitrary scripts in a shell where the shim has already exported keys.
- **Parser:** Inline `#` comments in `.env` values are stripped. Only valid env variable names are exported.
