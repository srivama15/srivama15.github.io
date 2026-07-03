#!/usr/bin/env bash
#
# personal-gh.sh — GitHub operations for THIS repo
#   (github.com/srivama15/srivama15.github.io) using Aman's PERSONAL identity,
#   never the work `gh` account (which cannot write to this personal repo).
#
# Two independent personal credentials are used, both outside `gh`:
#   * git over SSH  -> personal SSH key (~/.ssh/id_ed25519_personal), exactly
#                      like sync-gh.sh. Used for push.
#   * REST API      -> a personal Fine-grained PAT, resolved (in order) from:
#                        1. $SRIVAMA15_GH_TOKEN
#                        2. macOS Keychain item "srivama15-gh-token"
#                        3. file ~/.config/srivama15-gh/token (chmod 600)
#                      Used for pr / issue / comment. If no token is found the
#                      command FALLS BACK to opening a pre-filled browser page.
#
# This script is safe to commit: it contains NO secrets. The token lives only
# in your env / Keychain / a git-ignored file.
#
# Usage:
#   personal-gh.sh whoami
#   personal-gh.sh push [branch]
#   personal-gh.sh pr    --title T (--body-file F | --body B) [--base main] [--head branch] [--draft]
#   personal-gh.sh issue --title T (--body-file F | --body B)
#   personal-gh.sh comment (--pr N | --issue N) (--body-file F | --body B)
#
set -euo pipefail

OWNER="srivama15"
REPO="srivama15.github.io"
DEFAULT_BASE="main"
PERSONAL_KEY="$HOME/.ssh/id_ed25519_personal"
API="https://api.github.com"
WEB="https://github.com/${OWNER}/${REPO}"

err() { printf '✗ %s\n' "$*" >&2; }
info() { printf '→ %s\n' "$*" >&2; }
ok() { printf '✓ %s\n' "$*" >&2; }

# --- Safety: only ever operate on the personal repo ------------------------
guard_repo() {
  local url
  url="$(git remote get-url origin 2>/dev/null || echo '')"
  case "$url" in
    *"${OWNER}/${REPO}"*) : ;;
    *) err "origin is '$url', not ${OWNER}/${REPO}. Refusing (repo-scoped skill)."; exit 1 ;;
  esac
}

# --- Personal SSH key for git-over-SSH (deterministic, ignores work key) ----
git_ssh_env() {
  # -F /dev/null      ignore ~/.ssh/config (which defaults to the WORK key)
  # -i <personal key> force the personal key
  # IdentitiesOnly    ignore keys offered by ssh-agent (work key may be loaded)
  echo "ssh -F /dev/null -i $PERSONAL_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
}

# --- Resolve a personal PAT without touching `gh` --------------------------
resolve_token() {
  if [ -n "${SRIVAMA15_GH_TOKEN:-}" ]; then
    printf '%s' "$SRIVAMA15_GH_TOKEN"; return 0
  fi
  if command -v security >/dev/null 2>&1; then
    local t
    t="$(security find-generic-password -s srivama15-gh-token -w 2>/dev/null || true)"
    if [ -n "$t" ]; then printf '%s' "$t"; return 0; fi
  fi
  local f="$HOME/.config/srivama15-gh/token"
  if [ -f "$f" ]; then
    local t; t="$(tr -d '\n\r' < "$f")"
    if [ -n "$t" ]; then printf '%s' "$t"; return 0; fi
  fi
  return 1
}

# --- JSON encoding via python3 (guaranteed present on macOS) ---------------
json_kv() {
  # args: key1 val1 key2 val2 ... -> single JSON object
  python3 - "$@" <<'PY'
import json, sys
a = sys.argv[1:]
print(json.dumps({a[i]: a[i+1] for i in range(0, len(a), 2)}))
PY
}

urlencode() { python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read(), safe=""))'; }

open_browser() {
  local url="$1"
  # Personal workflow opens links in Brave (kept separate from the work Chrome
  # profile). Falls back to the system default browser if Brave isn't present.
  if open -a "Brave Browser" "$url" 2>/dev/null; then :; else open "$url"; fi
  ok "Opened in Brave (no personal token found): $url"
}

api() {
  # api <METHOD> <path> <json-body> <token> <out-file>
  # writes response body to <out-file>, echoes the HTTP status code to stdout.
  # (Runs inside command substitution, so it must NOT rely on globals.)
  local method="$1" path="$2" body="$3" token="$4" outfile="$5"
  curl -sS -o "$outfile" -w '%{http_code}' \
    -X "$method" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -d "$body" \
    "${API}${path}"
}

read_body() {
  # --body-file / --body -> stdout
  if [ -n "${BODY_FILE:-}" ]; then cat "$BODY_FILE"; else printf '%s' "${BODY:-}"; fi
}

# --------------------------- subcommands -----------------------------------

cmd_whoami() {
  guard_repo
  echo "repo:        ${OWNER}/${REPO}"
  echo "git remote:  $(git remote get-url origin)"
  echo "ssh key:     $PERSONAL_KEY $( [ -f "$PERSONAL_KEY" ] && echo '(present)' || echo '(MISSING)')"
  if resolve_token >/dev/null 2>&1; then
    echo "api token:   found (REST API writes enabled)"
  else
    echo "api token:   not found (pr/issue/comment will open a browser)"
    echo "             set one with: personal-gh.sh   (see SKILL.md 'Token setup')"
  fi
}

cmd_push() {
  guard_repo
  local branch="${1:-$(git rev-parse --abbrev-ref HEAD)}"
  info "Pushing '$branch' to origin with personal SSH key…"
  GIT_SSH_COMMAND="$(git_ssh_env)" git push -u origin "$branch"
  ok "Pushed $branch."
}

cmd_pr() {
  guard_repo
  local title="" base="$DEFAULT_BASE" head="" draft="false"
  while [ $# -gt 0 ]; do
    case "$1" in
      --title) title="$2"; shift 2;;
      --body-file) BODY_FILE="$2"; shift 2;;
      --body) BODY="$2"; shift 2;;
      --base) base="$2"; shift 2;;
      --head) head="$2"; shift 2;;
      --draft) draft="true"; shift;;
      *) err "unknown pr arg: $1"; exit 2;;
    esac
  done
  [ -n "$head" ] || head="$(git rev-parse --abbrev-ref HEAD)"
  [ -n "$title" ] || { err "pr requires --title"; exit 2; }
  local body; body="$(read_body)"

  local token
  if token="$(resolve_token)"; then
    info "Creating PR via REST API (head=$head base=$base draft=$draft)…"
    local payload resp
    payload="$(python3 - "$title" "$head" "$base" "$draft" <<'PY'
import json,sys
t,h,b,d=sys.argv[1:5]
print(json.dumps({"title":t,"head":h,"base":b,"draft":(d=="true")}))
PY
)"
    # merge body in (kept separate so large bodies stay safe)
    payload="$(python3 - "$payload" "$body" <<'PY'
import json,sys
o=json.loads(sys.argv[1]); o["body"]=sys.argv[2]; print(json.dumps(o))
PY
)"
    local resp_file code
    resp_file="$(mktemp)"
    code="$(api POST "/repos/${OWNER}/${REPO}/pulls" "$payload" "$token" "$resp_file")"
    if [ "$code" = "201" ]; then
      ok "PR created: $(python3 -c 'import json,sys;print(json.load(sys.stdin)["html_url"])' < "$resp_file")"
    else
      err "API returned $code:"; cat "$resp_file" >&2; rm -f "$resp_file"; exit 1
    fi
    rm -f "$resp_file"
  else
    local q tq; q="$(printf '%s' "$body" | urlencode)"; tq="$(printf '%s' "$title" | urlencode)"
    open_browser "${WEB}/compare/${base}...${head}?expand=1&title=${tq}&body=${q}"
  fi
}

cmd_issue() {
  guard_repo
  local title=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --title) title="$2"; shift 2;;
      --body-file) BODY_FILE="$2"; shift 2;;
      --body) BODY="$2"; shift 2;;
      *) err "unknown issue arg: $1"; exit 2;;
    esac
  done
  [ -n "$title" ] || { err "issue requires --title"; exit 2; }
  local body; body="$(read_body)"

  local token
  if token="$(resolve_token)"; then
    info "Creating issue via REST API…"
    local payload payload_body resp_file code
    payload="$(json_kv title "$title" body "$body")"
    resp_file="$(mktemp)"
    code="$(api POST "/repos/${OWNER}/${REPO}/issues" "$payload" "$token" "$resp_file")"
    if [ "$code" = "201" ]; then
      ok "Issue created: $(python3 -c 'import json,sys;print(json.load(sys.stdin)["html_url"])' < "$resp_file")"
    else
      err "API returned $code:"; cat "$resp_file" >&2; rm -f "$resp_file"; exit 1
    fi
    rm -f "$resp_file"
  else
    local q tq; q="$(printf '%s' "$body" | urlencode)"; tq="$(printf '%s' "$title" | urlencode)"
    open_browser "${WEB}/issues/new?title=${tq}&body=${q}"
  fi
}

cmd_comment() {
  guard_repo
  local num="" kind=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --pr) num="$2"; kind="pr"; shift 2;;
      --issue) num="$2"; kind="issue"; shift 2;;
      --body-file) BODY_FILE="$2"; shift 2;;
      --body) BODY="$2"; shift 2;;
      *) err "unknown comment arg: $1"; exit 2;;
    esac
  done
  [ -n "$num" ] || { err "comment requires --pr N or --issue N"; exit 2; }
  local body; body="$(read_body)"

  local token
  if token="$(resolve_token)"; then
    info "Adding comment to #$num via REST API…"
    local payload resp_file code
    payload="$(json_kv body "$body")"
    resp_file="$(mktemp)"
    # issues + PRs share the issue-comments endpoint
    code="$(api POST "/repos/${OWNER}/${REPO}/issues/${num}/comments" "$payload" "$token" "$resp_file")"
    if [ "$code" = "201" ]; then
      ok "Comment added: $(python3 -c 'import json,sys;print(json.load(sys.stdin)["html_url"])' < "$resp_file")"
    else
      err "API returned $code:"; cat "$resp_file" >&2; rm -f "$resp_file"; exit 1
    fi
    rm -f "$resp_file"
  else
    [ "$kind" = "pr" ] && open_browser "${WEB}/pull/${num}" || open_browser "${WEB}/issues/${num}"
  fi
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    whoami)  cmd_whoami "$@";;
    push)    cmd_push "$@";;
    pr)      cmd_pr "$@";;
    issue)   cmd_issue "$@";;
    comment) cmd_comment "$@";;
    *) cat >&2 <<EOF
personal-gh.sh — personal-identity GitHub ops for ${OWNER}/${REPO}
Subcommands: whoami | push [branch] | pr | issue | comment
See .github/skills/personal-gh-ops/SKILL.md for details.
EOF
       exit 2;;
  esac
}
main "$@"
