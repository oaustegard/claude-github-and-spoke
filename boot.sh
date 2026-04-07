#!/bin/bash
# Minimal boot: install gh + authenticate
# Called by SessionStart hook. stdout goes into Claude's context window.
set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# ── Source credentials ──
for envfile in "$PROJECT_DIR"/*.env "$PROJECT_DIR"/.env /mnt/project/*.env; do
    [ -f "$envfile" ] && { set -a; . "$envfile" 2>/dev/null; set +a; } || true
done

# ── Wait for network ──
for i in 1 2 3 4 5; do
    curl -sf --max-time 5 -o /dev/null "https://github.com" && break
    echo "Waiting for network (attempt $i/5)..."
    sleep $((i * 2))
done

# ── Install gh if not present ──
if ! command -v gh &>/dev/null; then
    echo "Installing gh CLI..."
    GH_VER=$(curl -sL https://api.github.com/repos/cli/cli/releases/latest \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'].lstrip('v'))")
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VER}/gh_${GH_VER}_linux_amd64.tar.gz" \
        | tar -xz --strip-components=2 -C /usr/local/bin "gh_${GH_VER}_linux_amd64/bin/gh"
    echo "✓ gh $GH_VER installed"
else
    echo "✓ gh already installed ($(gh --version | head -1))"
fi

# ── Authenticate ──
if [ -n "$GH_TOKEN" ]; then
    echo "$GH_TOKEN" | gh auth login --with-token 2>/dev/null
    GH_USER=$(gh api user -q .login 2>/dev/null || echo "unknown")
    echo "✓ Authenticated as $GH_USER"
else
    echo "⚠ No GH_TOKEN found — gh will be unauthenticated"
fi
