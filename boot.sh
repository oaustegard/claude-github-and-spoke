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
    # Use redirect trick to avoid API rate limits (no auth needed)
    GH_VER=$(curl -sIL -o /dev/null -w '%{url_effective}' https://github.com/cli/cli/releases/latest | grep -oP '[^/v]+$')
    if [ -z "$GH_VER" ]; then GH_VER="2.74.0"; fi  # fallback
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VER}/gh_${GH_VER}_linux_amd64.tar.gz" \
        | tar -xz --strip-components=2 -C /usr/local/bin "gh_${GH_VER}_linux_amd64/bin/gh"
    echo "✓ gh $GH_VER installed"
else
    echo "✓ gh already installed ($(gh --version | head -1))"
fi

# ── Authenticate ──
# `gh auth status` reports a valid token as invalid in this environment.
# Probe /user for the status code instead; never echo the header.
if [ -n "$GH_TOKEN" ]; then
    echo "$GH_TOKEN" | gh auth login --with-token 2>/dev/null || true
    CODE=$(curl -s -o /dev/null -w '%{http_code}' \
        -H "Authorization: Bearer $GH_TOKEN" https://api.github.com/user || true)
    if [ "$CODE" = "200" ]; then
        echo "✓ Token valid (authenticated as $(gh api user -q .login 2>/dev/null || echo unknown))"
    else
        echo "⚠ Token probe returned $CODE — if calls fail, suspect the agent proxy, not the token"
    fi
else
    echo "⚠ No GH_TOKEN found — gh will be unauthenticated"
fi

# Repos beyond this one are reached with the add_repo tool, not with a wider
# token: the proxy scopes by session repo set. See CLAUDE.md.
