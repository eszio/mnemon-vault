#!/usr/bin/env bash
# install.sh — set up mnemon-vault on a new machine
# Run from inside the cloned repo: ~/.mnemon-vault/install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
SETTINGS_FILE="${HOME}/.claude/settings.json"

echo "=== mnemon-vault install ==="
echo ""

# 1. Install age if missing
if ! command -v age &>/dev/null; then
    echo "[1/5] Installing age..."
    OS="$(uname -s)"
    case "$OS" in
        Darwin)
            if command -v brew &>/dev/null; then
                brew install age
            else
                echo "  Homebrew not found. Install from: https://brew.sh" >&2
                exit 1
            fi
            ;;
        Linux)
            if command -v apt-get &>/dev/null; then
                sudo apt-get install -y age
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y age
            else
                echo "  Unsupported Linux package manager." >&2
                echo "  Install age manually: https://github.com/FiloSottile/age/releases" >&2
                exit 1
            fi
            ;;
        *)
            echo "  Unsupported OS: $OS" >&2
            echo "  Install age manually: https://github.com/FiloSottile/age/releases" >&2
            exit 1
            ;;
    esac
    echo "  age installed: $(age --version)"
else
    echo "[1/5] age already installed: $(age --version)"
fi

# 2. Install mnemon if missing
if ! command -v mnemon &>/dev/null; then
    echo "[2/5] Installing mnemon..."
    if command -v go &>/dev/null; then
        go install github.com/mnemon-dev/mnemon@latest
    else
        echo "  Please install mnemon: go install github.com/mnemon-dev/mnemon@latest"
        exit 1
    fi
else
    echo "[2/5] mnemon already installed: $(mnemon --version 2>/dev/null || echo ok)"
fi

# 3. Symlink binary
echo "[3/5] Symlinking mnemon-vault to ${BIN_DIR}..."
mkdir -p "$BIN_DIR"
chmod +x "$SCRIPT_DIR/mnemon-vault"
ln -sf "$SCRIPT_DIR/mnemon-vault" "$BIN_DIR/mnemon-vault"
echo "  Symlinked."

# 3b. Seed members.txt from the example if this clone doesn't have one yet
if [ ! -f "$SCRIPT_DIR/members.txt" ] && [ -f "$SCRIPT_DIR/members.txt.example" ]; then
    cp "$SCRIPT_DIR/members.txt.example" "$SCRIPT_DIR/members.txt"
    echo "  Created members.txt from example — add your team's usernames, then:"
    echo "    git -C \"$SCRIPT_DIR\" add -f members.txt && git -C \"$SCRIPT_DIR\" commit -m 'chore: roster' && git -C \"$SCRIPT_DIR\" push"
fi

# 4. Configure git host identity (URL + username — required)
echo "[4/5] Configure git host identity..."
echo "  Supports any GitHub / GitLab / Gitea instance with a /{user}.keys endpoint."
echo "  Your SSH public keys must be registered there."
echo ""
"$SCRIPT_DIR/mnemon-vault" configure

# 5. Wire Claude Code hooks + env
echo "[5/5] Wiring Claude Code hooks in ${SETTINGS_FILE}..."
python3 - "$SETTINGS_FILE" "$SCRIPT_DIR" <<'PYEOF'
import json, sys, os

settings_path = sys.argv[1]
sync_dir = sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

# env: set MNEMON_STORE=team as default
env = settings.setdefault("env", {})
if "MNEMON_STORE" not in env:
    env["MNEMON_STORE"] = "team"
    print("  Added MNEMON_STORE=team to env")
else:
    print(f"  MNEMON_STORE already set to: {env['MNEMON_STORE']}")

hooks = settings.setdefault("hooks", {})

# SessionStart: mnemon-vault pull (imports memories + outputs guide.md)
session_start = hooks.setdefault("SessionStart", [])
pull_cmd = "$HOME/.local/bin/mnemon-vault pull 2>/dev/null || true"
if not any("mnemon-vault pull" in str(h) for h in session_start):
    session_start.append({"hooks": [{"type": "command", "command": pull_cmd}]})
    print("  Added SessionStart hook: mnemon-vault pull")
else:
    print("  SessionStart hook already present")

# SessionEnd: mnemon-vault push
session_end = hooks.setdefault("SessionEnd", [])
push_cmd = "$HOME/.local/bin/mnemon-vault push 2>/dev/null || true"
if not any("mnemon-vault push" in str(h) for h in session_end):
    session_end.append({"hooks": [{"type": "command", "command": push_cmd}]})
    print("  Added SessionEnd hook: mnemon-vault push")
else:
    print("  SessionEnd hook already present")

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print("  settings.json updated.")
PYEOF

# 6. Create mnemon stores if not exist
echo ""
echo "Creating mnemon stores..."
mnemon store create team 2>/dev/null && echo "  Created: team" || echo "  Already exists: team"
mnemon store create personal 2>/dev/null && echo "  Created: personal" || echo "  Already exists: personal"

# 7. Pull existing memories
echo ""
echo "Importing team memories..."
"$BIN_DIR/mnemon-vault" pull 2>&1 | grep -v "^$" || true

echo ""
echo "=== Done ==="
echo ""
echo "mnemon-vault is ready. Next session will auto-push/pull."
echo ""
echo "Manual usage:"
echo "  mnemon-vault push    — push memories to team repo"
echo "  mnemon-vault pull    — pull and import team memories"
echo "  mnemon-vault status  — show sync state"
