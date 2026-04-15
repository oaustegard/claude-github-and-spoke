# Claude GitHub GitHub and Spoke

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
# Clone and work in a spoke repo (always under ./.spokes/ — see below)
gh repo clone myuser/some-project .spokes/some-project
cd .spokes/some-project

# Create branches, commits, PRs in spoke repos
gh pr create --repo myuser/some-project --title "Fix: ..." --body "..."

# View issues across your repos
gh issue list --repo myuser/some-project
```

### Spoke clone convention: `.spokes/`

**Always clone spoke repos to `./.spokes/<repo-name>` inside this workspace,
not to `/tmp/` or `/home/user/`.** The directory is gitignored, so spoke
checkouts never pollute the hub's git state.

**Why this matters.** Anthropic's container ships `/tmp/code-sign` (wired
into git as `gpg.ssh.program`) which forwards every commit-signing request
to a remote signing service. That service resolves its "source" field from
the signer's cwd and only recognizes paths inside the hub repo where the
session was started. Committing from a spoke clone located anywhere else
fails with:

```
signing server returned status 400: {"error":{"message":"missing source"}}
```

Cloning spokes under `./.spokes/` keeps the signer's cwd-walk inside the
hub, so signing works without per-repo `commit.gpgsign=false` hacks or
temp-directory shuffles.

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

- **Add more credentials**: Add `.env` files — `boot.sh` sources all `*.env`
- **Add session-end hooks**: Extend `settings.json` with `Stop`/`SessionEnd` hooks
- **Add system packages**: Add `apt-get install` or `pip install` lines to `boot.sh`
