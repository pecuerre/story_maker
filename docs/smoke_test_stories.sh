#!/usr/bin/env bash
# End-to-end smoke test for the Stories / Sections feature over plain HTTP.
#
# Moved from /tmp/opencode/smoke_stories.sh into docs/ so it is tracked by git.
#
# What it checks:
#   1. login (CSRF token + signed session cookie)
#   2. top bar exposes /u/<slug>/s (universe dropdown) and the current story's sections link
#   3. stories index renders (cards, counts, "New story")
#   4. the universe-level /u/<slug>/sections URL is invalid (404)
#   5. a story's sections page renders that story's sections only
#   6. creating a second story works and its empty sections page renders
#   7. a story id from another universe is rejected (404)
#
# Usage:
#   bash docs/smoke_test_stories.sh
#   BASE=http://localhost:3000 EMAIL=lotr@lotr PASSWORD=lotr bash docs/smoke_test_stories.sh
#
# Requires a running server (development DB). It creates one story and deletes
# it again at the end. Cookie jar goes to ${TMPDIR:-/tmp}/smoke_cookies.txt.

set -u

# Always run from the repository root so `bin/rails` works from any cwd.
cd "$(dirname "$0")/.." || exit 1

BASE="${BASE:-http://localhost:3000}"
EMAIL="${EMAIL:-lotr@lotr}"
PASSWORD="${PASSWORD:-lotr}"
export UNIVERSE="${UNIVERSE:-lotr}"
JAR="${TMPDIR:-/tmp}/smoke_cookies.txt"
rm -f "$JAR"

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
LOGIN_CODE=$(curl -s -c "$JAR" -b "$JAR" -o /dev/null -w "%{http_code}" -X POST "$BASE/session" \
  --data-urlencode "authenticity_token=$TOKEN" \
  --data-urlencode "email_address=$EMAIL" \
  --data-urlencode "password=$PASSWORD")
check "login succeeds" "302" "$LOGIN_CODE"

# --- 2. sidebar links -------------------------------------------------------
SIDEBAR=$(curl -s -b "$JAR" "$BASE/u/$UNIVERSE")
echo "$SIDEBAR" | grep -oE 'href="/u/[^"]*/s[^"]*"' | sort -u > /tmp/smoke_sidebar.txt
contains "top bar links to the stories index" "href=\"/u/$UNIVERSE/s\"" /tmp/smoke_sidebar.txt

# --- 3. stories index -------------------------------------------------------
curl -s -b "$JAR" "$BASE/u/$UNIVERSE/s" -o /tmp/smoke_index.html -w "%{http_code}" \
  | grep -q 200 && echo "ok   - stories index returns 200" || { echo "FAIL - stories index"; fail=1; }
contains "index shows the New story button" "New story" /tmp/smoke_index.html

# --- 4. universe-level sections URL is invalid ------------------------------
OLD_CODE=$(curl -s -b "$JAR" -o /dev/null -w "%{http_code}" "$BASE/u/$UNIVERSE/sections")
check "universe-level /u/<slug>/sections is invalid" "404" "$OLD_CODE"

# --- 5. first story's sections page ----------------------------------------
FIRST_STORY=$(grep -oE "/u/$UNIVERSE/s/[0-9]+/sections" /tmp/smoke_index.html | head -1 | grep -oE '[0-9]+')
[ -n "$FIRST_STORY" ] || { echo "FAIL - no story link found on index"; exit 1; }
SECTIONS_CODE=$(curl -s -b "$JAR" -o /tmp/smoke_sections.html -w "%{http_code}" \
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

NEW_STORY=$(curl -s -b "$JAR" "$BASE/u/$UNIVERSE/s" \
  | grep -B2 -A2 "Smoke Test Story" | grep -oE "/u/$UNIVERSE/s/[0-9]+\"" | grep -oE '[0-9]+' | head -1)
[ -n "$NEW_STORY" ] || { echo "FAIL - new story not listed"; exit 1; }

NEW_PAGE=$(curl -s -b "$JAR" "$BASE/u/$UNIVERSE/s/$NEW_STORY/sections")
echo "$NEW_PAGE" > /tmp/smoke_new_sections.html
contains "new story's sections page renders its own header" "Story: Smoke Test Story" /tmp/smoke_new_sections.html

# --- 7. cross-universe story id is rejected ---------------------------------
OTHER_UNIVERSE_STORY=$(bin/rails runner 'puts Story.where.not(universe_id: Universe.find_by!(slug: ENV.fetch("UNIVERSE", "lotr")).id).first&.id' 2>/dev/null || true)
if [ -n "$OTHER_UNIVERSE_STORY" ]; then
  X_CODE=$(curl -s -b "$JAR" -o /dev/null -w "%{http_code}" \
    "$BASE/u/$UNIVERSE/s/$OTHER_UNIVERSE_STORY/sections")
  check "story from another universe is rejected" "404" "$X_CODE"
else
  echo "skip - only one universe in the DB, cross-universe check skipped"
fi

# --- cleanup ----------------------------------------------------------------
if [ -n "${NEW_STORY:-}" ]; then
  bin/rails runner "Story.find($NEW_STORY).destroy!" >/dev/null 2>&1 \
    && echo "ok   - removed smoke-test story $NEW_STORY" \
    || echo "warn - could not remove smoke-test story $NEW_STORY (delete it manually)"
fi
rm -f "$JAR" /tmp/smoke_sidebar.txt /tmp/smoke_index.html /tmp/smoke_sections.html \
       /tmp/smoke_new_sections.html

echo
[ "$fail" = "0" ] && echo "SMOKE TEST PASSED" || echo "SMOKE TEST FAILED"
exit "$fail"
