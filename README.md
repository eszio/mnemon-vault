# mnemon-vault

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey?logo=linux)](README.md)
[![Encryption](https://img.shields.io/badge/encryption-age-brightgreen)](https://github.com/FiloSottile/age)
[![Shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)](mnemon-vault)
[![ShellCheck](https://github.com/eszio/mnemon-vault/actions/workflows/lint.yml/badge.svg)](https://github.com/eszio/mnemon-vault/actions/workflows/lint.yml)

> Cross-device, cross-team memory sync for [mnemon](https://github.com/mnemon-dev/mnemon) — encrypted with age, distributed via git.

---

## Overview

mnemon-vault solves two problems:

| Problem | Solution |
|---|---|
| Your AI memories live only on one machine | Per-device encrypted files synced via git |
| Team members can't share project knowledge | Team store shared to all members; personal store private to you |

Each device pushes its own file — zero git conflicts by design.  
SSH public keys are fetched directly from your git host — no separate key management.

---

## How It Works

```
SessionStart                          SessionEnd
──────────────────────────────────    ──────────────────────────────────────
git pull                              export mnemon DB → JSON
↓                                     ↓
age decrypt (SSH private key)         SHA-256 hash ← compare with stored hash
↓                                     ↓ (skip if unchanged)
mnemon import → team store            age encrypt (all team SSH public keys)
                                      ↓
output guide.md → AI model            git commit + push
```

**Encryption model — hybrid (age):**

```
file key (16B random) ──→ ChaCha20-Poly1305 ──→ ciphertext body (one copy)
                │
                ├──→ X25519-ECDH(alice_pub) ──→ wrapped key  ┐
                ├──→ X25519-ECDH(bob_pub)   ──→ wrapped key  ├── header stanzas
                └──→ RSA-OAEP(charlie_pub)  ──→ wrapped key  ┘
```

Each team member decrypts independently with their own SSH private key.  
Ciphertext is written **once** regardless of team size — O(1) storage per device.

**Storage optimization:** A SHA-256 hash of the plaintext is committed alongside each encrypted file. Re-encryption is skipped when memories haven't changed, preventing git history bloat from non-deterministic ciphertext.

---

## Stores

| Store | Default | Shared | Use for |
|---|---|---|---|
| `team` | ✅ yes (`MNEMON_STORE=team`) | All team members | Architecture, conventions, system facts, project decisions |
| `personal` | `--store personal` | You only | Preferences, sensitive context, personal workflow |

---

## Prerequisites

| Tool | Install |
|---|---|
| [mnemon](https://github.com/mnemon-dev/mnemon) | `go install github.com/mnemon-dev/mnemon@latest` |
| [age](https://github.com/FiloSottile/age) | `sudo apt install age` / `brew install age` |
| git | system package |
| Python 3 | system package |
| SSH key registered on your git host | Profile → Settings → SSH Keys |

> **SSH key types:** Ed25519 and RSA are supported. ECDSA is not supported by age — add an Ed25519 key to your git host if you only have ECDSA.

---

## Installation

### Team admin (once per team)

1. Create a **private** repo on your git host (e.g. `your-org/mnemon-memories`)
2. Clone this repo, point it at your private repo, and create the team roster:

```bash
git clone https://github.com/eszio/mnemon-vault.git ~/.mnemon-vault
cd ~/.mnemon-vault
git remote set-url origin git@github.com:your-org/mnemon-memories.git

# Create the team roster from the template (one git host username per line)
cp members.txt.example members.txt
$EDITOR members.txt

# members.txt is gitignored by default so the public template never ships a real
# roster — force-add it into your PRIVATE repo:
git add -f members.txt
git commit -m "chore: seed team roster"
git push -u origin main
```

> **Why a separate private repo?** Each team keeps their own encrypted memories in their own repo — this template just provides the tooling. Never push your memories to a public fork.
>
> **Why `git add -f`?** `members.txt` is gitignored so a real roster can never leak into a public fork of the template. You explicitly force-add it once into your private repo.

### Each team member (per machine)

```bash
git clone git@github.com:your-org/mnemon-memories.git ~/.mnemon-vault
~/.mnemon-vault/install.sh
```

`install.sh` will:
1. Install `age` (OS-aware: apt / dnf / brew)
2. Install `mnemon` if missing
3. Symlink `mnemon-vault` to `~/.local/bin/`
4. Prompt for your git host URL and username → verify SSH key fetch
5. Wire Claude Code hooks (`SessionStart` pull, `SessionEnd` push)
6. Set `MNEMON_STORE=team` as default in Claude Code settings
7. Import all existing team memories

### Updating to a new version

```bash
mnemon-vault update
```

This pulls the latest tooling from the public template into your private team repo — your roster (`members.txt`) and encrypted data are never touched. It automatically:

1. Registers `https://github.com/eszio/mnemon-vault.git` as the `upstream` remote (first run only)
2. Fetches upstream and checks out only the tooling files (`mnemon-vault`, `install.sh`, `guide.md`, `members.txt.example`, `README.md`, `CONTRIBUTING.md`)
3. Commits and pushes to your private repo — **the whole team receives the update**
4. Applies any Claude Code hook/settings migrations (`install.sh --hooks-only`)

Other machines pick up the new script automatically on their next session (the `SessionStart` pull). If the release notes mention changes to Claude Code hooks, run `~/.mnemon-vault/install.sh --hooks-only` on each machine once — it migrates `settings.json` in place, no prompts.

<details>
<summary>Manual equivalent</summary>

```bash
cd ~/.mnemon-vault
git remote add upstream https://github.com/eszio/mnemon-vault.git   # first time only
git fetch upstream
git checkout upstream/main -- mnemon-vault install.sh guide.md members.txt.example README.md CONTRIBUTING.md
git commit -m "chore: update mnemon-vault tooling from upstream"
git push
./install.sh --hooks-only
```

</details>

---

## Usage

```bash
mnemon-vault configure   # set git host URL and username (once per machine)
mnemon-vault push        # export → encrypt → push to git
mnemon-vault pull        # git pull → decrypt → import into mnemon
mnemon-vault status      # show sync state, device files, recent commits
mnemon-vault update      # pull tooling updates from the public template
mnemon-vault keygen      # show which SSH keys will be used
```

### Memory commands (Claude Code)

```bash
# Team memory (default — shared with everyone):
mnemon remember "<fact>" --cat <fact|decision|insight|context> --imp <1-5>

# Personal memory (private to you):
mnemon --store personal remember "<fact>" --cat preference --imp <1-5>
```

**Rule of thumb:** *"Would a teammate benefit from knowing this?"* → team. Otherwise → personal.

---

## Team Management

> `members.txt` is gitignored (so the public template never ships a real roster).
> In your private repo, always stage it with `git add -f`.

### Add a member

1. Ask them to register an **Ed25519 or RSA** SSH key on your git host (ECDSA is not supported by age — it is skipped automatically)
2. Append their git host username to `members.txt`
3. Commit and push

```bash
echo "newuser" >> members.txt
git add -f members.txt
git commit -m "chore(members): add newuser"
git push
```

On each team member's next `push`, the new member's key is automatically included in the encryption recipients.

### Remove a member

1. Delete their username from `members.txt`, commit and push

```bash
# (edit members.txt to remove the line, then)
git add -f members.txt
git commit -m "chore(members): remove olduser"
git push
```

2. Each team member's next `push` re-encrypts without the removed key

> **Note:** Historical git commits remain encrypted with the old key set. If the data is sensitive, rotate by having all members push fresh after the removal.

---

## Repository Structure

```
~/.mnemon-vault/
├── mnemon-vault                          ← main script
├── install.sh                           ← new machine setup
├── members.txt.example                  ← roster template (shipped)
├── members.txt                          ← your team roster (gitignored; force-add in private repo)
├── guide.md                             ← AI routing instructions (output at SessionStart)
├── .gitignore                           ← excludes decrypted .json files + members.txt
└── data/
    ├── team/
    │   ├── insights-{device}.json.age     ← encrypted team memories
    │   └── insights-{device}.json.sha256  ← plaintext hash (skip re-encrypt if unchanged)
    └── personal/
        ├── insights-{device}.json.age     ← encrypted personal memories (own key only)
        └── insights-{device}.json.sha256  ← plaintext hash
```

Per-machine config (not in repo):
```
~/.config/mnemon-vault/config   ← GIT_HOST_USER, GIT_HOST_URL
```

---

## Security Notes

- **This repo must remain private.** Memories are encrypted, but git history is permanent.
- **No credentials in memory.** Treat mnemon stores like code — secrets belong in `.env` and Vault.
- **Personal files are unreadable by teammates** — only your own SSH private key can decrypt them.
- SSH key rotation: add the new key to your git host → your next `push` picks it up automatically.

---

## Compatibility

| OS | age install | Status |
|---|---|---|
| Ubuntu / Debian | `sudo apt install age` | ✅ |
| RHEL / Fedora | `sudo dnf install age` | ✅ |
| macOS | `brew install age` | ✅ |
| Other | [manual](https://github.com/FiloSottile/age/releases) | ✅ |

| Git host | SSH keys endpoint | Status |
|---|---|---|
| GitHub | `https://github.com/{user}.keys` | ✅ |
| GitLab | `https://gitlab.com/{user}.keys` | ✅ |
| Gitea (self-hosted) | `https://your-host/{user}.keys` | ✅ |

SSH key types supported by age: **Ed25519**, **RSA** (2048+)
