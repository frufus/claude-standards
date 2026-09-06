LIB="plugins/dev-standards/hooks/lib/verification.js"

count() { printf '%s' "$1" | node "$LIB" 2>/dev/null; }

check "an all-pass report has no findings" \
  "$(count '# Verification: x

### login shows the form — pass
Proof: p.png
### empty list shows the empty state — pass
Proof: q.png')" "0"

check "an unanswered fail counts" \
  "$(count '### bad input is rejected — fail
Finding: it was accepted')" "1"

check "an unanswered not-verifiable counts" \
  "$(count '### offline mode — not verifiable
Finding: no way to cut the network')" "1"

check "an answered fail does not count" \
  "$(count '### bad input is rejected — fail
Finding: it was accepted
Answer: fixed in fix: reject malformed input')" "0"

check "an answered rejection does not count" \
  "$(count '### offline mode — not verifiable
Finding: no way to cut the network
Answer: rejected — covered by the unit test for the repository layer')" "0"

check "the answer must belong to its own section" \
  "$(count '### a — fail
Finding: x
Answer: fixed
### b — fail
Finding: y')" "1"

check "a plain hyphen before the verdict is accepted" \
  "$(count '### a - fail
Finding: x')" "1"

check "verdict matching is case-insensitive" \
  "$(count '### a — FAIL
Finding: x')" "1"

check "empty input is zero" "$(count '')" "0"
printf 'not a report at all' | node "$LIB" >/dev/null 2>&1
check "always exits 0" "$?" "0"
