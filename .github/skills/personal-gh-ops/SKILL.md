---
name: personal-gh-ops
description: GitHub operations (push, PR, issue, comment) for THIS repo (srivama15/srivama15.github.io) using Aman's personal identity instead of the `gh` CLI. Use whenever a task needs to push, open a PR, create an issue, or comment on this repo. The `gh` login here is tied to a separate work account that cannot write to this personal repo, so never use `gh` here; use this skill first.
license: personal use
---

# Personal GitHub Ops (this repo only)

This repo (`github.com/srivama15/srivama15.github.io`) is Aman's **personal**
GitHub project, but the `gh` login on this machine is tied to a separate
**work account** that cannot write to it: `gh pr create`, `gh issue create`,
etc. fail here with an authorization error. Do not use `gh` for this repo.

**Rule: for this repo, never reach for `gh`. Use `scripts/personal-gh.sh`.**
It uses Aman's personal credentials only, and never touches the work `gh` auth.

## When to use

Any push / PR / issue / comment on `srivama15/srivama15.github.io`. Do NOT run
`gh <write>` first and fall back, go straight to this skill.

`git commit` itself needs no special handling (author is already the personal
Gmail). Only **network** ops need the personal identity.

## How auth works (two separate personal credentials)

| Operation | Credential | Why |
|-----------|-----------|-----|
| `push` (git over SSH) | Personal SSH key `~/.ssh/id_ed25519_personal`, forced via `GIT_SSH_COMMAND` (`-F /dev/null -i <key> -o IdentitiesOnly=yes`) | Same approach as `sync-gh.sh`; ignores the work key in `~/.ssh/config` / ssh-agent. |
| `pr` / `issue` / `comment` (REST API) | Personal fine-grained PAT via `curl` | `gh` can't act as the personal account. |

The PAT is resolved, in order, from:
1. `$SRIVAMA15_GH_TOKEN`
2. macOS Keychain item `srivama15-gh-token`
3. `~/.config/srivama15-gh/token` (a git-ignored file, chmod 600)

**If no token is found, the script automatically falls back to opening a
pre-filled browser page** (compare page for PRs, new-issue page for issues) so
the op still completes with one click. No secret ever lives in this repo.

## Browser

All browser links for this personal repo open in **Brave** (`open -a "Brave
Browser"`), kept separate from the work Chrome profile, falling back to the
system default browser if Brave isn't installed. This applies both to the
script's built-in fallback and to any links the agent opens by hand while
working on this repo (e.g. the token-setup page). Do not use Chrome here.

> Note: direct `ssh` may be blocked by a local security hook, but `git push`
> with `GIT_SSH_COMMAND` set is fine (the hook only intercepts a top-level
> `ssh` command, not git's internal ssh subprocess). The script relies on push
> success/failure rather than an `ssh -T` pre-check.

## Usage

Run from the repo root. `allowed-tools: shell` is intentionally omitted, so
you approve the command the first time each session.

```bash
S=.github/skills/personal-gh-ops/scripts/personal-gh.sh

# Which identity will be used, and is a token configured?
bash "$S" whoami

# Push the current branch (or a named one) with the personal key
bash "$S" push
bash "$S" push amsrivas/some-branch

# Open a PR (writes a body file first, then passes it)
bash "$S" pr --title "Add X" --body-file /tmp/pr-body.md
bash "$S" pr --title "Add X" --body-file /tmp/pr-body.md --base main --head amsrivas/some-branch
bash "$S" pr --title "Draft X" --body-file /tmp/pr-body.md --draft

# Create an issue
bash "$S" issue --title "Add a Mentorship section" --body-file /tmp/issue-body.md

# Comment on a PR or issue (same endpoint for both)
bash "$S" comment --pr 2 --body-file /tmp/reply.md
bash "$S" comment --issue 1 --body "Looks good, merging after policy sign-off."
```

For multi-line PR/issue/comment bodies, write the body to a temp file with a
heredoc and pass `--body-file`, rather than a long `--body` string.

To link a PR to an issue, put `Closes #<n>` on the first line of the PR body.
GitHub shares one number sequence across issues and PRs, so create the issue
first, then the PR.

## One-time token setup (enables full automation, removes the browser step)

Create a **fine-grained personal access token** on your personal account
(github.com → Settings → Developer settings → Fine-grained tokens), scoped to
**only** `srivama15/srivama15.github.io`, with **Contents: Read/Write**,
**Pull requests: Read/Write**, **Issues: Read/Write**. Then store it one of
these ways (Keychain recommended):

```bash
# Recommended: macOS Keychain (no plaintext on disk)
security add-generic-password -s srivama15-gh-token -a "$USER" -w '<TOKEN>'

# OR a git-ignored file
mkdir -p ~/.config/srivama15-gh
printf '%s' '<TOKEN>' > ~/.config/srivama15-gh/token && chmod 600 ~/.config/srivama15-gh/token

# OR just export it for the session
export SRIVAMA15_GH_TOKEN='<TOKEN>'
```

Without a token everything still works via the browser fallback, you just click
"Create" once. The token is what makes PR/issue/comment fully hands-off.

## Guardrails

- The script hard-checks that `origin` is `srivama15/srivama15.github.io` and
  refuses to run otherwise, it is deliberately scoped to this one repo.
- It never invokes `gh` and never modifies `gh` auth.
- Contains no secrets and is safe to commit; keep the token outside the repo.
