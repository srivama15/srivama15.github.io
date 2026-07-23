# Copilot instructions

## GitHub operations

Auth differs by machine, so work out which one you are on first. If `sync-gh.sh`
and `gh-personal.sh` exist in the repo root, you are on the office Mac. If they
are absent, you are on my personal laptop (the common case).

### Personal laptop (default)

Here `gh` and git are already signed in to my private account (`srivama15`), so
everything lands on the right account with no extra steps. Commit first (never
push a branch you have not committed on), then push directly with `git push`.
Use plain `gh` for issues, comments, and other GitHub API calls. The
`sync-gh.sh` / `gh-personal.sh` helpers do not exist here and are not needed, so
do not go looking for them or treat their absence as a blocker.

### Office Mac

There `gh` is configured for the official LinkedIn work account, so a normal
push or `gh` call would fall back to the work token and land on the wrong
account. `gh-personal.sh` and `sync-gh.sh` are local, git-ignored helpers in the
repo root that exist specifically to bypass that fallback and force my personal
account. For issues, comments, and other GitHub API operations, use
`./gh-personal.sh`. For any remote push, commit first and run `./sync-gh.sh`
from the repo root (add `--force` for a force-with-lease push). Never commit,
create, or modify these scripts.

## Writing style

No em dashes. Use commas, periods, colons, parentheses, or "so".
