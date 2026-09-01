GS="plugins/dev-standards/hooks/lib/git-subject.js"
MSGHOOK="plugins/dev-standards/hooks/check-commit-msg.sh"

sub() { printf '%s' "$1" | node "$GS" 2>/dev/null; }

warn() {
    printf '%s' "$1" |
        node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(JSON.stringify({tool_input:{command:s}})))' |
        bash "$MSGHOOK" 2>/dev/null
}

# Git's subject is the first line. Measuring the whole message reported a
# perfectly well-formed commit as an over-long subject, which is the loudest
# possible way for a hook to be wrong: it fires on correct work.
one_m='git commit -m "feat: a short subject

A body line that runs well past seventy-two characters so that measuring the whole message would report a violation."'

check "the subject of a subject-plus-body message is its first line" \
  "$(sub "$one_m")" "feat: a short subject"

check "such a commit draws no warning" "$(warn "$one_m")" ""

# The body may itself be many lines; still only the first counts.
many='git commit -m "fix: keep it short

First body paragraph.

Second body paragraph that is also quite long, past the limit on its own."'

check "a multi-paragraph body does not become the subject" \
  "$(sub "$many")" "fix: keep it short"

# And a genuinely over-long subject must still be caught - the fix must not
# have turned the check off.
long='git commit -m "feat: this single-line subject is deliberately far beyond the seventy-two character limit the standard sets"'

contains "an over-long single-line subject is still reported" "$(warn "$long")" "characters"

# A trailing carriage return must not become part of the subject, or the
# Conventional Commits pattern would still match while the length is off by one.
check "a carriage return is not part of the subject" \
  "$(printf '%s' 'git commit -m "feat: x'$'\r''
body"' | node "$GS" 2>/dev/null)" "feat: x"
