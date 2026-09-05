// Reads a raw shell command line on stdin and writes `push`, `pr` or
// `archive` when a command at a command position is `git push`,
// `gh pr create` or `openspec archive` — the three moments a change
// leaves the machine. Writes nothing otherwise.
//
// Hooks must never fail on unexpected input: every failure path ends in
// no output and exit code 0.
const { tokenize, isCommandStart } = require("./tokenize.js");

const SHIP = [
  { words: ["git", "push"], kind: "push" },
  { words: ["gh", "pr", "create"], kind: "pr" },
  { words: ["openspec", "archive"], kind: "archive" },
];

function shipKind(tokens) {
  for (let idx = 0; idx < tokens.length; idx++) {
    if (tokens[idx].type !== "word" || !isCommandStart(tokens, idx)) continue;
    for (const { words, kind } of SHIP) {
      const match = words.every(
        (w, k) => tokens[idx + k] && tokens[idx + k].type === "word" && tokens[idx + k].value === w
      );
      if (match) return kind;
    }
  }
  return null;
}

let raw = "";
process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  try {
    const kind = shipKind(tokenize(raw));
    if (kind) process.stdout.write(kind);
  } catch {
    // degrade to empty output
  }
});
