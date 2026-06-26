# Claude GitHub GitHub and Spoke

**Give Claude Code on the Web authenticated `gh` CLI access to all your repos.**

This is a minimal template for the hub/spoke working model: one repo boots
the session with GitHub access, then you work across any repo your token reaches.

## Quick Start

1. Use this repo as a template (or fork it)
2. Create `.env` with `GH_TOKEN=ghp_...`
3. Open in Claude Code on the Web
4. You now have `gh` across all your repos

## What's in the box

| File | Purpose |
|------|---------|
| `boot.sh` | Installs `gh` CLI, authenticates with your token |
| `.claude/settings.json` | SessionStart hook + denies MCP GitHub server |
| `CLAUDE.md` | Agent instructions — tells Claude about hub/spoke |

## How it works

The `SessionStart` hook runs `boot.sh`, which:
1. Sources all `*.env` files for credentials
2. Installs `gh` CLI if not already present (~3s)
3. Authenticates with `$GH_TOKEN`

The MCP GitHub server is denied in settings because it can only see the hub
repo. The `gh` CLI, authenticated with your PAT, can reach any repo — making
spoke operations seamless.

## Fallback: opening PRs on the *hub* repo when the MCP is disabled

This template **denies the MCP GitHub server** (above), so your PAT via `gh` is
the only GitHub channel — and the agent proxy App-gates PAT calls that name the
**hub repo** on the `/repos/{owner}/{repo}` path. Spoke PRs are unaffected, but
`gh pr create` on the hub repo itself fails with:

> GitHub access is not enabled for this session. An org admin must connect the
> Claude GitHub App for this organization.

**Sanctioned fix:** connect the Claude GitHub App for your org and re-enable the
MCP GitHub server (remove the `github` entry from `deniedMcpServers`). The MCP
uses the App token, which isn't subject to the PAT gate — this is the durable path.

**Fallback (keep the MCP off):** `scripts/hub_pr.py` opens hub PRs through
GitHub's legacy **by-id** route `/repositories/{id}/...`, which carries no
`{owner}/{repo}` substring for the proxy to match (the repo id resolves via the
ungated `/search` endpoint):

```bash
git push -u origin <branch>
python3 scripts/hub_pr.py create --head <branch> --base main \
    --title "..." --body "..."
```

Use the fallback **only on a hub repo you own** — i.e. your PAT holds
`admin`/`push` on it. Under that precondition it routes your own token around a
credential-*routing* preference; without it you'd be circumventing real access
control. It also relies on the proxy gating by path-string only — if that's
tightened, the helper breaks and the MCP path is the one that survives.

## Background

This extracts the core GitHub integration from
[claude-workspace](https://github.com/oaustegard/claude-workspace)
(see [PR #12](https://github.com/oaustegard/claude-workspace/pull/12))
into a standalone template anyone can use.

For the full story, see the [Container Layer Hack](https://austegard.com/blog/custom-container-layers-for-claudes-ephemeral-machines.html) post.

## License

MIT
