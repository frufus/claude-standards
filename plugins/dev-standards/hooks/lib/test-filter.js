// Filters a test runner's combined output. Keeps: step markers from
// scripts/verify, failure headers and the lines that follow them,
// assertion lines, and the summary. Drops per-test pass lines. Always
// exits 0 — the pipeline's status is the runner's, not the filter's.
const KEEP = [
  /^== /, /^verify: /,                                        // scripts/verify
  /\bFAIL\b/, /^\s*[×✗]/, /AssertionError/, /^\s*Error[: ]/,  // vitest
  /Test Files\s/, /^\s*Tests\s/, /Duration\s/, /Snapshots\s/, /⎯⎯/,
  /\bFAILED\b/, /\bERROR\b/, /^E\s{2,}/, /^_{3,} .* _{3,}$/,      // pytest
  /^={3,} .*(passed|failed|error|skipped).* ={3,}$/,
  /^\s+at .*\(.*:\d+:\d+\)$/, /^[^\s].*:\d+(:\d+)?: /,       // locations
  /error TS\d+/, /^\s*\d+:\d+\s+error/,                      // tsc, eslint
];
const HEADER = /\bFAIL\b|^\s*[×✗]|\bFAILED\b|\bERROR\b|^_{3,} .* _{3,}$/;
const AFTER = 12;      // lines kept after a failure header
const CAP = 300;       // hard cap on lines forwarded

let raw = "";
process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  const lines = raw.split(/\r?\n/);
  if (lines.length && lines[lines.length - 1] === "") lines.pop();
  const out = [];
  let tail = 0;
  for (const line of lines) {
    const header = HEADER.test(line);
    if (header) tail = AFTER;
    if (header || tail > 0 || KEEP.some((re) => re.test(line))) {
      out.push(line);
      if (!header && tail > 0) tail--;
    }
  }
  const shown = out.slice(0, CAP);
  process.stdout.write(shown.join("\n"));
  if (shown.length < lines.length) {
    process.stdout.write(`\n(filtered: ${shown.length} of ${lines.length} lines; rerun with a pipe or redirection to see everything)\n`);
  } else if (shown.length) {
    process.stdout.write("\n");
  }
  process.exit(0);
});
