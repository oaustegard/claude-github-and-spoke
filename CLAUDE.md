# Claude GitHub and Spoke

This repo is the **hub**: it boots the session with an authenticated `gh` CLI
and tells you how to reach the user's other repos.

## Reaching another repo

The session starts scoped to the repos attached to it. Call `add_repo` to add
one, then clone it.

```
add_repo(owner="<owner>", repo="<repo>", access="push")
```

Read the tool's reply rather than assuming what it did:

- `status: "read_available"` means nothing was attached. The repo is public and
  the git proxy serves anonymous `clone`/`fetch` directly. You can read files.
  The GitHub API, `git push`, LFS objects and `register_repo_root` do **not**
  cover it. Call again with `access:"push"` if you need any of those.
- `status: "appended"` means the repo is attached with credentials and the API
  works against it.

Then:

1. Clone inline in the same turn — one clone, not in parallel with other work,
   with a timeout around ten minutes. `git index-pack` looks stalled while
   unpacking and is not.
2. Call `register_repo_root` with the absolute clone path so the repo's
   `CLAUDE.md` and skills load.

Three failure modes worth naming:

- **Do not pre-check the repo before calling `add_repo`.** No `git ls-remote`,
  no unauthenticated `curl`. Private repos return 404 to unauthenticated probes
  even when the session is authorized, and that false negative reads as "the
  repo does not exist".
- **`MCP error -32003: requires approval` is a prompt, not a failure.** It shows
  the user an approval dialog while handing you an error string. Retry the
  identical call once. If it errors again, ask the user to switch the session's
  permission mode to Auto. Do not loop, and do not route around it.
- **The tool's server name segment is not stable.** It has appeared as
  `mcp__Claude_Code_Remote__add_repo` and in a UUID form. Read it off the tool
  list instead of typing it from memory; a remembered spelling returns
  `No such tool available`, which reads as though the tool is gone.

## Clone paths

| Case | Path |
|---|---|
| attached (`access="push"`) | `/home/user/<repo>` |
| anonymous read | `/home/user/<owner>/<repo>` |
| inside this hub | `.spokes/<repo>` — gitignored, keeps the hub's `git status` clean |

Do not reuse an anonymous-read checkout after attaching the repo; clone fresh at
the attached path.

## Channels

| Channel | Works |
|---|---|
| `gh` / REST, attached repo | yes, reads and writes |
| `gh` / REST, unattached repo | no — 403 naming `add_repo` |
| anonymous `git clone`/`fetch`, public repo | yes, no attach needed |
| `raw.githubusercontent.com` + `Authorization: Bearer $GH_TOKEN` | yes, any repo including private and unattached |
| `mcp__github__search_*` | yes, globally, private repos included |
| `api.github.com/search/*` over HTTP | no — use the MCP search tools |
| `api.github.com/repositories/{id}` | no |
| GraphQL | no, whatever credential you supply |

The proxy scopes by session repo set rather than by credential. A PAT does not
reach further than the MCP server does, so do not reach for one when a call 403s
— call `add_repo`.

Leave the MCP GitHub server enabled. It opens PRs on attached repos, and its
`search_*` tools are the only GitHub search available.

## Credentials

`boot.sh` sources `*.env` and authenticates `gh`.

**`gh auth status` reports a valid token as invalid.** Do not diagnose from it.
Probe instead, reading the status code alone:

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
    -H "Authorization: Bearer $GH_TOKEN" https://api.github.com/user
```

200 proves the token. Anything else is the proxy. Never `curl -v` against
`api.github.com` — it echoes the `Authorization` header into the transcript.

**Never put `$GH_TOKEN` in a URL.** git prints the URL to stdout and `-u`
persists it into `.git/config`. Use `gh`, or:

```bash
git -c 'credential.helper=!f() { echo "username=x-access-token"; echo "password=$GH_TOKEN"; }; f' \
    push origin <branch>
```

## Commit signing

The container wires `/tmp/code-sign` as `gpg.ssh.program` with
`commit.gpgsign=true`. Commits from clones outside this hub succeeded when
measured on 2026-08-21, and produced unsigned commits rather than errors. Older
containers rejected them with `missing source`. If you hit that, commit with
`-c commit.gpgsign=false`.

## Setup

1. Fork or use as a template.
2. Add `.env` (gitignored) with `GH_TOKEN=github_pat_...`.
3. Open in Claude Code on the Web. The `SessionStart` hook runs `boot.sh`.

## Customizing

- **More credentials**: add `.env` files; `boot.sh` sources all `*.env`.
- **Session-end hooks**: extend `settings.json` with `Stop`/`SessionEnd`.
- **System packages**: add `apt-get install` or `pip install` lines to `boot.sh`.
