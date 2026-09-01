JF="plugins/dev-standards/hooks/lib/json-fields.js"

out=$(printf '%s' '{"tool_input":{"file_path":"C:\\src\\a.ts"},"cwd":"C:\\proj"}' \
      | node "$JF" tool_input.file_path cwd 2>/dev/null)
check "reads two dotted paths" "$out" "$(printf 'C:\\src\\a.ts\tC:\\proj')"

out=$(printf '%s' '{"changes":[{"id":"a"},{"id":"b"}],"root":{"path":"/p"}}' \
      | node "$JF" changes.length root.path 2>/dev/null)
check "array length and nested path" "$out" "$(printf '2\t/p')"

out=$(printf '%s' '{"root":null}' | node "$JF" root.path 2>/dev/null)
check "null parent yields empty" "$out" ""

out=$(printf '%s' '{"a":{"b":1}}' | node "$JF" a 2>/dev/null)
check "object value yields empty" "$out" ""

out=$(printf '%s' 'not json at all' | node "$JF" a.b 2>/dev/null)
check "unparseable input yields empty" "$out" ""

printf '%s' 'not json' | node "$JF" a.b >/dev/null 2>&1
check "unparseable input still exits 0" "$?" "0"

out=$(printf '%s' '{"m":"line one\nline two"}' | node "$JF" m 2>/dev/null)
check "newlines inside a value are flattened" "$out" "line one line two"

# --raw exists for one caller: a commit message whose newlines are the only
# thing separating its subject from its body. Squashing them there turned a
# well-formed commit into a reported violation.
multi='{"tool_input":{"command":"line one\nline two"}}'

check "the default still squashes line breaks into one line" \
  "$(printf '%s' "$multi" | node "$JF" tool_input.command | wc -l | tr -d ' ')" "1"

check "--raw keeps them" \
  "$(printf '%s' "$multi" | node "$JF" --raw tool_input.command | wc -l | tr -d ' ')" "2"

check "--raw is not mistaken for a path" \
  "$(printf '%s' "$multi" | node "$JF" --raw tool_input.command | head -1)" "line one"

check "--raw still degrades to empty on a missing path" \
  "$(printf '%s' "$multi" | node "$JF" --raw nope.missing | tr -d '\n')" ""
