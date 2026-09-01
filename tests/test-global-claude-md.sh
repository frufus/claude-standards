G="plugins/dev-standards/templates/global/CLAUDE.md"
g=$(cat "$G" 2>/dev/null)

contains "carries the proposal-first rule"   "$g" "proposal"
contains "carries the branch convention"     "$g" "claude/"
contains "carries Conventional Commits"      "$g" "Conventional Commits"
contains "carries the 72-character limit"    "$g" "72"
contains "carries the ADR location"          "$g" "docs/adr/"
contains "carries the review rule"           "$g" "settled with a test"
contains "carries the deviation rule"        "$g" "before it is built"
contains "carries the language convention"   "$g" "English"

# Headless services, CLIs and scripts have no user-facing strings, yet
# every session pays for a line that assumes otherwise. The i18n rule
# belongs to the web profile's own files, not the layer every project
# loads regardless of whether it has a UI.
not_contains "does not carry the i18n rule"  "$g" "i18n"

# Spec section 4.5 budgets this file at roughly 50 lines. It is loaded
# into every session in every directory, so growth here is paid for
# continuously and by every project, including the ones it does not
# apply to.
lines=$(wc -l < "$G" 2>/dev/null || echo 999)
check "stays within its budget" "$([ "$lines" -le 60 ] && echo ok)" "ok"
