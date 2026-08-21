# Claude GitHub and Spoke

**A minimal Claude Code on the Web hub: boot one repo, reach the rest.**

Open a CCotw session in this repo and you get a `gh` CLI authenticated with your
token, plus instructions that tell Claude how to pull your other repos into the
session as it needs them.

## Quick start

1. Use this repo as a template, or fork it.
2. Add a `.env` file (gitignored) containing `GH_TOKEN=github_pat_...`.
3. Open the repo in Claude Code on the Web.
4. Ask Claude to work on another repo. It calls `add_repo`, clones, and carries on.

## How a session reaches other repos

A CCotw session starts scoped to the repos attached to it — this one, plus
anything the environment lists as a source. Everything GitHub-shaped goes
through an agent proxy that enforces that scope.

`add_repo` is the tool that changes it. It is an MCP tool the harness gives the
model, and it widens the session's scope mid-turn:

```
add_repo(owner="you", repo="other-project", access="push")
```

The two access levels do different things:

- **`access="read"`** on a public repo attaches nothing. It replies
  `status: "read_available"` and points you at the git proxy, which already
  serves anonymous `clone` and `fetch` for public repos. You get files. You do
  not get the GitHub API, `git push`, Git LFS objects, or `register_repo_root`.
- **`access="push"`** performs the real attach. It runs the repository-access
  check server-side and attaches credentials, so the API and `gh` reach that
  repo afterwards. The response reports `status: "appended"`.

The check runs server-side, so you get what your connected GitHub account
already has and the tool refuses the rest. What it widens is the session's
default scope.

After a `push` attach, clone the repo and then call `register_repo_root` so its
`CLAUDE.md` and skills load.

## Which channel reaches what

Measured 2026-08-21 from a live CCotw session, one fine-grained PAT throughout.

| Channel | Result |
|---|---|
| `gh` / REST on an **attached** repo | works — reads and writes |
| `gh` / REST on an **unattached** repo | **403**, body names `add_repo` |
| anonymous `git clone` / `fetch` of any **public** repo | works, no attach needed |
| `raw.githubusercontent.com` + `Authorization: Bearer $GH_TOKEN` | works for any repo, **including private and unattached** |
| `mcp__github__search_*` | works globally, including metadata for private unattached repos |
| `api.github.com/search/*` over plain HTTP | 403 — use the MCP search tools |
| `api.github.com/repositories/{id}` (legacy by-id route) | 403, attached repos included |
| GraphQL | blocked, whatever credential you supply |
| codeload / archives / release assets, unattached | 403 |

The 403 body is worth reading rather than guessing at:

```json
{"message":"GitHub access to this repository is not enabled for this session.
  Use add_repo to request access. If add_repo answers that read access is already
  available and you need GitHub API or write access, call add_repo again with
  access:\"push\" to attach the repository with credentials."}
```

Two consequences for how you configure a hub. The proxy scopes by session repo
set rather than by credential, so supplying your own PAT does not widen reach —
`gh` and the MCP server hit the same wall at the same place. And the MCP GitHub
server is worth leaving **on**: it opens PRs on attached repos, and its
`search_*` tools are the only search that works at all.

## Files

| File | Purpose |
|------|---------|
| `boot.sh` | Sources `*.env`, installs `gh`, authenticates, probes the token |
| `.claude/settings.json` | SessionStart hook |
| `CLAUDE.md` | Tells Claude how to reach spokes, and where to put them |

## Where to put spoke clones

`add_repo` will tell you to clone to `/home/user/<repo>` for an attached repo,
or `/home/user/<owner>/<repo>` for the anonymous read lane. Both work. Cloning
into `.spokes/<repo>` inside this hub also works and keeps the checkout
gitignored, so spoke files never show up in the hub's `git status`.

Give any clone a generous timeout, around ten minutes. A shallow pack through
the proxy can take five, and `git index-pack` looks stalled while it unpacks.
An HTTP 429 is this session's two-concurrent-operation cap rather than a GitHub
rate limit: sleep and retry once.

## Debugging authentication

**`gh auth status` reports a working token as invalid.** Measured in the same
second: `gh auth status` printed `The token in GH_TOKEN is invalid` while
`gh api repos/oaustegard/claude-github-and-spoke` returned the repo. Ignore it.

Probe the token itself, and read the status code alone so the header never
reaches stdout:

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
    -H "Authorization: Bearer $GH_TOKEN" https://api.github.com/user
```

200 means the token is fine and any other failure you are seeing is the proxy.
Never run `curl -v` against `api.github.com` — verbose mode echoes the
`Authorization` header into the transcript.

**Never put the token in a URL.** `git push https://x-access-token:$GH_TOKEN@...`
echoes it to stdout, and `-u` writes it into `.git/config`. Use `gh`, or a
one-shot credential helper:

```bash
git -c 'credential.helper=!f() { echo "username=x-access-token"; echo "password=$GH_TOKEN"; }; f' \
    push origin <branch>
```

## Changes from the June 2026 version

The June 2026 version was built on a different premise: deny the MCP GitHub
server, authenticate `gh` with a PAT, and reach every repo that way. The proxy
tightened after that, and by August all three of its central claims measure
false.

- It said a PAT via `gh` reaches any repo. Unattached repos now return 403 on
  the named `/repos/{owner}/{repo}` route.
- It said the proxy gated PAT calls naming the **hub** repo, which is why
  `gh pr create` failed there. That route returns 200.
- It shipped `scripts/hub_pr.py`, which opened hub PRs through the legacy
  `/repositories/{id}` route on the grounds that the path carries no
  `{owner}/{repo}` substring for the proxy to match. That route now returns 403
  everywhere, and the `/search` call the script used to resolve the id returns
  403 too. The script is deleted.

The script's docstring named this risk when it was written: "this depends on the
proxy gating by path-string only. If that changes, this breaks."

Old `CLAUDE.md` also required spoke clones under `.spokes/` because the commit
signer at `/tmp/code-sign` resolved its source field from the signer's cwd and
rejected paths outside the hub with `missing source`. That failure did not
reproduce on 2026-08-21: commits from a clone at `/home/user/<repo>` succeeded.
If you do hit it, commit with `-c commit.gpgsign=false`.

## Background

Extracted from [claude-workspace](https://github.com/oaustegard/claude-workspace).
For the container-layer side of that setup, see the
[Container Layer Hack](https://austegard.com/blog/custom-container-layers-for-claudes-ephemeral-machines.html).

## License

MIT
