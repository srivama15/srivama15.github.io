# AGENTS.md

Instructions for AI coding agents working in this repo
(`github.com/srivama15/srivama15.github.io`, Aman's personal site, served via
GitHub Pages from the `main` branch).

## GitHub operations: use the personal identity, never `gh`

This is a **personal** repo, but the `gh` login on this machine is tied to a
separate **work account** that cannot write to it: any `gh` write here
(`gh pr create`, `gh issue create`, `gh api ...`) fails with an authorization
error. Do not use `gh` for this repo.

**Rule: for push / PR / issue / comment on this repo, use the
`personal-gh-ops` skill** at `.github/skills/personal-gh-ops/`. It goes straight
to the personal identity, so there is no "try `gh`, then fall back" step.

```bash
S=.github/skills/personal-gh-ops/scripts/personal-gh.sh
bash "$S" whoami                                   # show identity + token status
bash "$S" push [branch]                             # push via personal SSH key
bash "$S" pr    --title T --body-file F [--draft]   # open a PR (personal token)
bash "$S" issue --title T --body-file F             # create an issue
bash "$S" comment (--pr N | --issue N) --body-file F
```

How auth works (two separate personal credentials, never `gh`):

- **git push** uses the personal SSH key `~/.ssh/id_ed25519_personal`, forced via
  `GIT_SSH_COMMAND` (ignores the work key in `~/.ssh/config` / ssh-agent). Same
  approach as `sync-gh.sh` (a git-ignored, push-only helper).
- **PR / issue / comment** use a personal fine-grained token via the REST API,
  resolved from `$SRIVAMA15_GH_TOKEN`, then the macOS Keychain item
  `srivama15-gh-token`, then `~/.config/srivama15-gh/token`. If no token is
  found, the skill opens a pre-filled browser page instead.

The token needs, on this repo only, **Contents**, **Pull requests**, and
**Issues** set to Read/Write. It lives in the Keychain, never in this repo.

## Browser

Open links for this repo in **Brave**, not Chrome (the work Chrome profile is
kept separate). The skill's browser fallback already does this.

## Writing style (agent output)

No em dashes in commit messages, PR bodies, or docs. Use commas, periods,
colons, parentheses, or "so".

## Deploy note

`main` is the GitHub Pages source, so merging to `main` publishes the live site.
Anything under `.github/` (including this file and the skill) is not published.
