// Reads a verification.md on stdin and writes the number of unanswered
// findings: sections headed `### <scenario> — fail` or
// `### <scenario> — not verifiable` that carry no `Answer:` line before
// the next `###` heading. The dash may be an em dash, an en dash or a
// hyphen; the verdict is matched case-insensitively.
//
// Hooks must never fail on unexpected input: anything this script cannot
// read counts as zero findings and exits 0. A hook that crashes on a
// hand-edited report gets disabled, and then it protects nothing.
const VERDICT = /^###\s.*[—–-]\s*(fail|not verifiable)\s*$/i;

let raw = "";
process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  let unanswered = 0;
  try {
    let inFinding = false;
    let answered = false;
    const close = () => {
      if (inFinding && !answered) unanswered++;
    };
    for (const line of raw.split(/\r?\n/)) {
      if (line.startsWith("### ")) {
        close();
        inFinding = VERDICT.test(line);
        answered = false;
      } else if (inFinding && /^Answer:/.test(line)) {
        answered = true;
      }
    }
    close();
  } catch {
    unanswered = 0;
  }
  process.stdout.write(String(unanswered));
});
