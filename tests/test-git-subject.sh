GS="plugins/dev-standards/hooks/lib/git-subject.js"

subj() { printf '%s' "$1" | node "$GS" 2>/dev/null; }

check "the first -m wins over a later -m (subject-plus-body idiom)" \
  "$(subj 'git commit -m "feat: x" -m "body text"')" "feat: x"

check "combined -am takes the next token as the message" \
  "$(subj 'git commit -am "feat: x"')" "feat: x"

check "combined -asm takes the next token as the message" \
  "$(subj 'git commit -asm "feat: z"')" "feat: z"

check "git commit appearing only as plain text inside another command is not a commit" \
  "$(subj "echo 'git commit -m \"added the thing\"'")" ""

check "an apostrophe inside a double-quoted message survives" \
  "$(subj "git commit -m \"feat: don't break this\"")" "feat: don't break this"

check "an escaped inner quote does not truncate the subject" \
  "$(subj 'git commit -m "feat: subject with an escaped \" quote inside it that keeps going past seventeen characters total"')" \
  'feat: subject with an escaped " quote inside it that keeps going past seventeen characters total'

check "a real commit after && is still a commit" \
  "$(subj 'cd /tmp && git commit -m "added thing"')" "added thing"

check "a real commit after ; is still a commit" \
  "$(subj 'echo hi; git commit -m "added thing"')" "added thing"

check "-F - has no message visible in the command string" \
  "$(subj 'git commit -F -')" ""

check "--file also stays silent" \
  "$(subj 'git commit --file=msg.txt')" ""

check "--message= long form works" \
  "$(subj 'git commit --message="feat: y"')" "feat: y"

check "--message with a space-separated value works" \
  "$(subj 'git commit --message "feat: y"')" "feat: y"

check "a non-commit git command yields no subject" \
  "$(subj 'git status --short')" ""

check "a command with no git at all yields no subject" \
  "$(subj 'npm run test')" ""

printf 'not a shell command \x00 at all' | node "$GS" >/dev/null 2>&1
check "never throws, exits 0 on odd input" "$?" "0"
