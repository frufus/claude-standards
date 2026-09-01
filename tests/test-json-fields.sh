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
