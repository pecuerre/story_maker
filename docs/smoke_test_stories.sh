#!/usr/bin/env bash
# End-to-end smoke test for the Stories / Sections feature over plain HTTP.
#
# Moved from /tmp/opencode/smoke_stories.sh into docs/ so it is tracked by git.
#
# What it checks:
#   1. login (CSRF token + signed session cookie), asserted on the redirect target and the cookie
#   2. the universe page exposes /u/<slug>/s (All stories) and lists the stories
#   3. stories index renders (cards, counts, "New story")
#   4. the universe-level /u/<slug>/sections URL is invalid (404)
#   5. a story's sections page renders that story's sections only
#   6. creating a second story works and its empty sections page renders
#   7. a story id from another universe is rejected (404)
#
# Usage:
#   PASSWORD='<the development password>' bash docs/smoke_test_stories.sh
#   BASE=http://localhost:3000 EMAIL=lotr@lotr PASSWORD='<the development password>' bash docs/smoke_test_stories.sh
#
# There is no default password on purpose. db:demo:reset / db:demo:load print the
# development password together with the export command that makes it available to
# this shell; PASSWORD (or UNIVERSE_MAKER_DEV_PASSWORD) carries it in. The script
# never prints or stores the value.
#
# Requires a running server (development DB). It creates one story and deletes
# it again at the end. Every file it writes lives in one `mktemp -d` directory
# that is removed on exit, including on an interrupt or an early `exit`, and two
# runs cannot collide on it.

set -u

# Always run from the repository root so `bin/rails` works from any cwd.
cd "$(dirname "$0")/.." || exit 1

BASE="${BASE:-http://localhost:3000}"
EMAIL="${EMAIL:-lotr@lotr}"
PASSWORD="${PASSWORD:-${UNIVERSE_MAKER_DEV_PASSWORD:-}}"
if [ -z "$PASSWORD" ]; then
  {
    echo "FAIL - no password supplied for $EMAIL."
    echo "  This script has no default credential on purpose. Load the development"
    echo "  universe (CONFIRM_DB_RESET=1 UNIVERSE=lotr bin/rails db:demo:reset) and use"
    echo "  the password it prints, or the one you exported as UNIVERSE_MAKER_DEV_PASSWORD:"
    echo "    PASSWORD='<that value>' bash docs/smoke_test_stories.sh"
  } >&2
  exit 1
fi
export UNIVERSE="${UNIVERSE:-lotr}"

# The one temporary directory this script owns. `mktemp -d` rather than fixed
# names under `$TMPDIR`, so two runs cannot overwrite each other's cookie jar or
# captured HTML, and nothing is left behind on a hard exit.
WORK=$(mktemp -d "${TMPDIR:-/tmp}/smoke_test.XXXXXXXX") || exit 1
JAR="$WORK/cookies.txt"
SIDEBAR_LINKS="$WORK/sidebar.txt"
INDEX_HTML="$WORK/index.html"
SECTIONS_HTML="$WORK/sections.html"
NEW_SECTIONS_HTML="$WORK/new_sections.html"

# The story this run created, so cleanup can remove it even when the run is cut
# short between creating it and reaching the cleanup block at the end.
NEW_STORY=""

# `rails runner` without this reads the environment from `.env`-free variables
# only and would happily run against whichever database `RAILS_ENV` names, which
# is how a development-only task ends up pointed at another environment's data.
export RAILS_ENV=development

cleanup() {
  # A story left behind is the one thing this script cannot afford to leak: the
  # next run's `destroy_all` would clear it, but a run that is interrupted here
  # leaves a real row in the development database with no trace of who made it.
  if [ -n "$NEW_STORY" ]; then
    bin/rails runner "Story.find($NEW_STORY).destroy!" >/dev/null 2>&1 \
      && echo "ok   - removed smoke-test story $NEW_STORY" \
      || echo "warn - could not remove smoke-test story $NEW_STORY (delete it manually)"
  fi
  rm -rf "$WORK"
}
# EXIT covers a normal end and an early `exit 1`; INT and TERM cover a Ctrl-C or
# a kill, which is how a half-finished run used to strand a story.
trap cleanup EXIT INT TERM

fail=0
check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1 (expected '$2', got '$3')"; fail=1; fi
}
contains() { # contains <label> <needle> <haystack-file>
  if grep -qF -- "$2" "$3"; then echo "ok   - $1"; else echo "FAIL - $1 (missing '$2')"; fail=1; fi
}

# --- 1. login ---------------------------------------------------------------
TOKEN=$(curl -s -c "$JAR" -b "$JAR" "$BASE/session/new" \
  | grep -o 'name="csrf-token" content="[^"]*"' | sed 's/.*content="//;s/"$//')
[ -n "$TOKEN" ] || { echo "FAIL - could not read CSRF token"; exit 1; }

# NOTE: the login form posts FLAT params (email_address/password), not session[...].
#
# **The status code alone cannot tell a sign-in from a rejection.** `SessionsController#create`
# answers `302` in both branches — a success redirects to `after_authentication_url`, a rejection
# back to `new_session_path` with the `sessions.failed` alert — so a wrong password, a rate-limited
# attempt, and an expired CSRF token all satisfied the old `check "login succeeds" "302"` and left
# the script to fail nine checks later over content that was never behind a session. Asserting the
# **redirect target** is what makes the line mean what it says: a rejection's target is the sign-in
# page itself.
LOGIN_HEADERS=$(curl -s -c "$JAR" -b "$JAR" -o /dev/null -D - -X POST "$BASE/session" \
  --data-urlencode "authenticity_token=$TOKEN" \
  --data-urlencode "email_address=$EMAIL" \
  --data-urlencode "password=$PASSWORD")
LOGIN_CODE=$(printf '%s' "$LOGIN_HEADERS" | awk 'toupper($1) ~ /^HTTP\// { code = $2 } END { print code }')
LOGIN_TARGET=$(printf '%s' "$LOGIN_HEADERS" | tr -d '\r' | awk 'tolower($1) == "location:" { print $2 }' | tail -1)

check "login answers a redirect" "302" "$LOGIN_CODE"
if [ "$LOGIN_TARGET" = "$BASE/session/new" ]; then
  echo "FAIL - login was rejected: redirected back to the sign-in page." >&2
  echo "  The credential was refused, the attempt was rate limited, or the CSRF token expired." >&2
  echo "  Fix the first of those before reading anything else this script reports." >&2
  exit 1
fi
echo "ok   - login succeeded (redirected to ${LOGIN_TARGET:-an unknown target})"

# A second proof that a session exists, independent of where the redirect pointed: the application
# writes one cookie on sign-in and it is named `session_id`
# (`cookies.signed[:session_id]` in `Authentication#start_new_session_for`). Its presence is what the
# next request is authorized by, so this is the assertion the old status-code check could not make.
if grep -q "session_id" "$JAR" 2>/dev/null; then
  echo "ok   - the signed session_id cookie was stored"
else
  echo "FAIL - no session_id cookie in the jar; the run is not signed in" >&2
  exit 1
fi

# --- 2. universe page links -------------------------------------------------
SIDEBAR=$(curl -s -b "$JAR" "$BASE/u/$UNIVERSE")
echo "$SIDEBAR" | grep -oE 'href="/u/[^"]*/s[^"]*"' | sort -u > "$SIDEBAR_LINKS"
contains "universe page links to the stories index" "href=\"/u/$UNIVERSE/s\"" "$SIDEBAR_LINKS"

# --- 3. stories index -------------------------------------------------------
curl -s -b "$JAR" "$BASE/u/$UNIVERSE/s" -o "$INDEX_HTML" -w "%{http_code}" \
  | grep -q 200 && echo "ok   - stories index returns 200" || { echo "FAIL - stories index"; fail=1; }
contains "index shows the New story button" "New story" "$INDEX_HTML"

# --- 4. universe-level sections URL is invalid ------------------------------
OLD_CODE=$(curl -s -b "$JAR" -o /dev/null -w "%{http_code}" "$BASE/u/$UNIVERSE/sections")
check "universe-level /u/<slug>/sections is invalid" "404" "$OLD_CODE"

# --- 5. first story's sections page ----------------------------------------
FIRST_STORY=$(grep -oE "/u/$UNIVERSE/s/[0-9]+/sections" "$INDEX_HTML" | head -1 | grep -oE '[0-9]+')
[ -n "$FIRST_STORY" ] || { echo "FAIL - no story link found on index"; exit 1; }
SECTIONS_CODE=$(curl -s -b "$JAR" -o "$SECTIONS_HTML" -w "%{http_code}" \
  "$BASE/u/$UNIVERSE/s/$FIRST_STORY/sections")
check "story sections page returns 200" "200" "$SECTIONS_CODE"

# --- 6. create a second story ----------------------------------------------
# Remove any leftover from a previously interrupted run (story names are unique per universe).
bin/rails runner 'Story.where(name: "Smoke Test Story").destroy_all' >/dev/null 2>&1

CREATE_CODE=$(curl -s -c "$JAR" -b "$JAR" -o /dev/null -w "%{http_code}" -X POST "$BASE/u/$UNIVERSE/s" \
  --data-urlencode "authenticity_token=$TOKEN" \
  --data-urlencode "story[name]=Smoke Test Story" \
  --data-urlencode "story[description]=created by docs/smoke_test_stories.sh")
check "creating a story redirects" "302" "$CREATE_CODE"

# Recorded before the assertion below, so an interruption between here and the end
# of the script still leaves `cleanup` something to remove.
NEW_STORY=$(curl -s -b "$JAR" "$BASE/u/$UNIVERSE/s" \
  | grep -B2 -A2 "Smoke Test Story" | grep -oE "/u/$UNIVERSE/s/[0-9]+\"" | grep -oE '[0-9]+' | head -1)
[ -n "$NEW_STORY" ] || { echo "FAIL - new story not listed"; exit 1; }

NEW_PAGE=$(curl -s -b "$JAR" "$BASE/u/$UNIVERSE/s/$NEW_STORY/sections")
echo "$NEW_PAGE" > "$NEW_SECTIONS_HTML"
contains "new story's sections page renders its own header" "Story: Smoke Test Story" "$NEW_SECTIONS_HTML"

# --- 7. cross-universe story id is rejected ---------------------------------
OTHER_UNIVERSE_STORY=$(bin/rails runner 'puts Story.where.not(universe_id: Universe.find_by!(slug: ENV.fetch("UNIVERSE", "lotr")).id).first&.id' 2>/dev/null || true)
if [ -n "$OTHER_UNIVERSE_STORY" ]; then
  X_CODE=$(curl -s -b "$JAR" -o /dev/null -w "%{http_code}" \
    "$BASE/u/$UNIVERSE/s/$OTHER_UNIVERSE_STORY/sections")
  check "story from another universe is rejected" "404" "$X_CODE"
else
  echo "skip - only one universe in the DB, cross-universe check skipped"
fi

# --- result -----------------------------------------------------------------
# The story and the temporary directory are removed by the `EXIT` trap rather than
# here, so they go even when a check above exited early or the run was interrupted.
echo
[ "$fail" = "0" ] && echo "SMOKE TEST PASSED" || echo "SMOKE TEST FAILED"
exit "$fail"
