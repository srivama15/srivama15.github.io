# Copilot instructions

## GitHub operations

For issues, comments, and other GitHub API operations, use `./gh-personal.sh`
from the repo root when it is present. If it is absent, fall back to the `gh`
CLI.

For any remote push, commit first and run `./sync-gh.sh` from the repo root when
it is present. Add `--force` for a force-with-lease push. If the script is
absent, fall back to the `gh` CLI.

Both scripts are local, git-ignored helpers. Do not commit, create, or modify
them.

## Writing style

No em dashes. Use commas, periods, colons, parentheses, or "so".
