# Git Bash's grep strips carriage returns before matching, so a grep for
# CR passes on a CRLF file. Ask git instead: the index is the truth about
# what was committed, and one CRLF file under plugins/ or tests/ is a
# hook, skill or template that will misbehave on the machines this plugin
# exists for.
check "no tracked file under plugins/ or tests/ is CRLF in the index" \
  "$(git ls-files --eol plugins tests 2>/dev/null | grep -c 'i/crlf')" "0"
