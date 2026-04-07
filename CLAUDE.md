# Claude GitHub Hub and Spoke

This repo is the **hub** — it configures your Claude Code on the Web session
with authenticated GitHub access via the `gh` CLI.

## What this gives you

After session start, you have `gh` authenticated with your token. This means
you can work across **any repo your token can reach** — not just this one.

## The hub/spoke model

- **Hub** (this repo): boots the session, installs `gh`, authenticates
- **Spokes** (your other repos): where actual work happens

From any CCotw session started in this repo, you can:
```bash
# Clone and work in a spoke repo
gh repo clone myuser/some-project /tmp/some-project
cd /tmp/some-project

# Create branches, commits, PRs in spoke repos
gh pr create --repo myuser/some-project --title "Fix: ..." --body "..."

# View issues across your repos
gh issue list --repo myuser/some-project
```

## Why deny the MCP GitHub server?

Claude Code's built-in MCP GitHub server only sees the hub repo. By denying
it in `settings.json` and using `gh` CLI instead, you get uniform access to
**all** repos — hub and spokes alike.

## Setup

1. Fork or clone this repo
2. Create a `.env` file (gitignored) with your GitHub PAT:
   ```
   GH_TOKEN=ghp_your_token_here
   ```
3. Open the repo in Claude Code on the Web
4. The `SessionStart` hook runs `boot.sh` automatically

## Customizing

- **Add system packages**: Edit `Containerfile` with additional `RUN` lines
- **Add more credentials**: Add `.env` files — `boot.sh` sources all `*.env`
- **Add session-end hooks**: Extend `settings.json` with `Stop`/`SessionEnd` hooks

## Container layer caching (optional)

The `Containerfile` uses the container-layer format. If you set up caching
(see [claude-container-layers](https://github.com/oaustegard/claude-container-layers)),
`gh` gets restored from cache instead of re-downloaded each session.
Without caching, `boot.sh` installs `gh` from GitHub Releases directly (~3s).
