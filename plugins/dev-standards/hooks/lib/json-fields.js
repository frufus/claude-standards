// Reads a JSON object on stdin and writes the values at the dotted paths
// given as arguments, tab-separated, on a single line.
//
// With --raw the values keep their line breaks. Callers reading several fields
// with `IFS=$'\t' read` need the single-line guarantee; a caller asking for one
// field that may legitimately contain newlines — a commit message — needs the
// opposite, and squashing them there destroys the only thing separating a
// subject from its body.
//
// Hooks must never fail on unexpected input: a shape this script did not
// expect has to degrade to an empty field, not to a stack trace that
// Claude Code surfaces as a broken hook. So every failure path here ends
// in an empty string and exit code 0.
let raw = "";
process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  let root;
  try {
    root = JSON.parse(raw);
  } catch {
    root = undefined;
  }

  const args = process.argv.slice(2);
  const keepLineBreaks = args.includes("--raw");
  const paths = args.filter((arg) => arg !== "--raw");

  const fields = paths.map((path) => {
    let value = root;
    for (const key of path.split(".")) {
      if (value === null || typeof value !== "object") return "";
      value = value[key];
    }
    // Objects and arrays have no scalar rendering. `changes.length`
    // reaches a number through the same walk, which is the only way a
    // caller needs to ask about a collection.
    if (value === null || value === undefined || typeof value === "object") return "";
    // The output is one tab-separated line; anything in a value that
    // would break that becomes a space — unless the caller asked for the
    // value as it stands.
    const text = String(value);
    return keepLineBreaks ? text : text.replace(/[\t\r\n]/g, " ");
  });

  process.stdout.write(fields.join("\t") + "\n");
});
