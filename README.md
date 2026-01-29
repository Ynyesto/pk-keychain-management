# Private Key MacOS Keychain Management

Use your Ethereum (or other EVM) private key from `.env` **without storing it in plaintext**. Works with **any** tool that reads a private key from an environment variable—Hardhat, Foundry, or anything else. No tool-specific vaults or secret managers; just one Keychain item and two scripts.

## Goal

- Store the private key **once** in macOS Keychain (encrypted, unlocked with your Mac password).
- In **any** project `.env`, put only the **name** of that Keychain item (e.g. `PRIVATE_KEY=ETH_DEV_PRIVATE_KEY`).
- When you run your tool, it sees the **actual** key in the environment, as if you had pasted it in `.env`—but the key never sits in a file in plaintext.

You keep the usual “set a var in `.env`, run the tool” workflow, without putting the key in plaintext and without adopting each framework’s own secret solution.

## Why this is convenient

- **Same `.env` pattern everywhere**: Use whatever variable name the tool expects (`PRIVATE_KEY`, `PKEY`, `SECRET_KEY`, etc.) with the value set to the Keychain item name. One convention across all EVM projects.
- **No plaintext key in repos**: `.env` only contains a placeholder name; the real key lives in Keychain. Safe to commit a `.env.example` with that placeholder.
- **No paid services**: Uses macOS Keychain only; no 1Password or other subscriptions.
- **Framework-agnostic**: One setup for Hardhat, Foundry, and any other tool that reads a private key from an env var.

## Scripts

| Script | Purpose |
|--------|--------|
| **keychain-env-shim.sh** | A *shim*: a small adapter that runs on every `cd` (in zsh). It looks for a `.env` in the current (or parent) directory, finds lines whose value is a Keychain item name, fetches the secret from Keychain, and exports the same variable name with that secret. When you `cd` into a project, the right env vars are set automatically; when you leave, they’re unset. |
| **with-keychain** | Wrapper for one-off runs: `with-keychain -- <command>`. Reads `.env`, resolves Keychain refs into env vars, then runs your command. Use when the shim isn’t active (e.g. IDE terminal that didn’t load `~/.zshrc`, non-zsh shell, or CI), or when you want to run a command without `cd`-ing into the project first. |

## Install

1. **Put the scripts on your PATH** (e.g. `~/.local/bin`). From this repo:

   ```bash
   cd /path/to/pk-keychain-management
   mkdir -p ~/.local/bin
   cp keychain-env-shim.sh with-keychain ~/.local/bin/
   chmod +x ~/.local/bin/with-keychain
   ```

   Or symlink so updates in this repo are used automatically:

   ```bash
   cd /path/to/pk-keychain-management
   ln -sf "$(pwd)/keychain-env-shim.sh" ~/.local/bin/keychain-env-shim.sh
   ln -sf "$(pwd)/with-keychain" ~/.local/bin/with-keychain
   chmod +x ~/.local/bin/with-keychain
   ```

   Ensure `~/.local/bin` is in your `PATH` (e.g. in `~/.zshrc`: `export PATH="$HOME/.local/bin:$PATH"`).

2. **Store your key in Keychain once** (use a name you’ll reuse in every project):

   ```bash
   security add-generic-password -U -s "ETH_DEV_PRIVATE_KEY" -a "your-account-name" -w "0xYOUR_PRIVATE_KEY"
   ```

   Replace `your-account-name` and `0xYOUR_PRIVATE_KEY` with your choice and your actual key (with or without `0x`).

3. **Use the shim (optional but recommended)** so keys are resolved automatically when you `cd` into a project:

   In `~/.zshrc` add:

   ```bash
   source "$HOME/.local/bin/keychain-env-shim.sh"
   ```

   Reload the shell (`exec zsh` or open a new terminal). When you `cd` into a directory that has a `.env` with e.g. `PRIVATE_KEY=ETH_DEV_PRIVATE_KEY`, that variable will be set to the real key from Keychain.

## Usage in a project

In the project’s `.env`, use the variable name your **tool** expects, and set the value to the Keychain item name:

- **Hardhat / Foundry** (and most tools): `PRIVATE_KEY=ETH_DEV_PRIVATE_KEY`
- Or any other name: `PKEY=ETH_DEV_PRIVATE_KEY`, `SECRET_KEY=ETH_DEV_PRIVATE_KEY`, `ETH_SEPOLIA_KEY=ETH_DEV_PRIVATE_KEY`, etc.

You can also use the explicit form: `SOME_VAR=keychain:ETH_DEV_PRIVATE_KEY`.

Then:

- **With the shim**: `cd` to the project and run your tool (e.g. `npx hardhat run ...`, `forge script ...`). The key is already in the environment.
- **Without the shim**: Run `with-keychain -- npx hardhat run ...` (or `with-keychain -- forge script ...`, etc.).

## Requirements

- macOS (uses `security` and Keychain).
- zsh (for the shim; `with-keychain` is plain bash and works in any shell).
