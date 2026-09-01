// Reads a JSON object on stdin and writes the values at the dotted paths
// given as arguments, tab-separated, on a single line.
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

  const fields = process.argv.slice(2).map((path) => {
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
    // would break that becomes a space.
    return String(value).replace(/[\t\r\n]/g, " ");
  });

  process.stdout.write(fields.join("\t") + "\n");
});
