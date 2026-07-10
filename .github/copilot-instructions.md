# Copilot instructions

## Pushing and GitHub operations

See `AGENTS.md` for the required workflow. Push via the repo's own helper
script, never raw `ssh`, `git push`, or `gh`: the environment blocks the `ssh`
command, and `gh` is logged in to the wrong account for this repo. The helper
selects the correct identity and key internally.

## Writing style

No em dashes. Use commas, periods, colons, parentheses, or "so".
