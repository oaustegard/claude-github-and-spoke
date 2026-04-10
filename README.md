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

## Background

This extracts the core GitHub integration from
[claude-workspace](https://github.com/oaustegard/claude-workspace)
(see [PR #12](https://github.com/oaustegard/claude-workspace/pull/12))
into a standalone template anyone can use.

For the full story, see the [Container Layer Hack](https://austegard.com/blog/custom-container-layers-for-claudes-ephemeral-machines.html) post.

## License

MIT
