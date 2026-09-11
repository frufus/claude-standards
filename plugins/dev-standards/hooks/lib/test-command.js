// Reads a raw shell command line on stdin and writes `filter` when the
// whole line is one test-runner invocation at a command position:
// `npm test`, `npm run test`, `npx vitest`, `pnpm test`, `pnpm vitest`,
// `vitest`, `pytest`, `uv run pytest`, `python -m pytest`, or
// `scripts/verify`. Writes nothing otherwise — including when the line
// carries any operator (`&&`, `||`, `;`, `|`, newline) or a redirection,
// because a rewrite must wrap exactly one command and nothing else.
//
// Hooks must never fail on unexpected input: every failure path ends in
// no output and exit code 0.
const { tokenize, isCommandStart } = require("./tokenize.js");

const RUNNERS = [
  ["npm", "test"], ["npm", "run", "test"], ["npx", "vitest"],
  ["pnpm", "test"], ["pnpm", "vitest"], ["vitest"],
  ["pytest"], ["uv", "run", "pytest"], ["python", "-m", "pytest"],
  ["scripts/verify"], ["./scripts/verify"], ["bash", "scripts/verify"],
];

function testKind(tokens) {
  if (tokens.length === 0) return "";
  if (tokens.some((t) => t.type !== "word")) return "";           // any operator
  if (tokens.some((t) => /[<>]/.test(t.value))) return "";         // any redirection
  if (!isCommandStart(tokens, 0)) return "";
  const words = tokens.map((t) => t.value);
  const hit = RUNNERS.some((r) => r.every((w, k) => words[k] === w));
  return hit ? "filter" : "";
}

let raw = "";
process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  try {
    const kind = testKind(tokenize(raw));
    if (kind) process.stdout.write(kind);
  } catch { /* silence */ }
});
