// Reads a raw shell command line on stdin and writes the kind of the
// first destructive git command at a command position — `force-push`,
// `hard-reset`, `clean` or `branch-delete` — or nothing. These four are
// the shapes that destroy something the working tree cannot restore;
// everything else git does is reversible enough to stay a reminder.
//
// Hooks must never fail on unexpected input: every failure path ends in
// no output and exit code 0.
const { tokenize, isCommandStart } = require("./tokenize.js");

function segmentArgs(tokens, from) {
  const args = [];
  for (let j = from; j < tokens.length && tokens[j].type === "word"; j++) args.push(tokens[j].value);
  return args;
}

function classify(sub, args) {
  if (sub === "push" && args.some((a) => a === "-f" || a === "--force" || a.startsWith("--force-with-lease"))) return "force-push";
  if (sub === "reset" && args.includes("--hard")) return "hard-reset";
  if (sub === "clean" && args.some((a) => a === "--force" || /^-[a-zA-Z]*f[a-zA-Z]*$/.test(a))) return "clean";
  if (sub === "branch" && (args.includes("-D") || (args.includes("--delete") && args.includes("--force")))) return "branch-delete";
  return null;
}

// Global options precede the subcommand — `git -C dir reset --hard`,
// `git --no-pager push --force`, `git -c core.x=1 clean -fd` — so these
// have to be skipped before the subcommand word is read.
const GLOBAL_OPTS_WITH_VALUE = new Set(["-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env"]);

function destructiveKind(tokens) {
  for (let idx = 0; idx < tokens.length; idx++) {
    const t = tokens[idx];
    if (t.type !== "word" || t.value !== "git" || !isCommandStart(tokens, idx)) continue;
    let j = idx + 1;
    while (tokens[j] && tokens[j].type === "word" && tokens[j].value.startsWith("-")) {
      const opt = tokens[j].value;
      j++;
      if (GLOBAL_OPTS_WITH_VALUE.has(opt)) j++;
    }
    const next = tokens[j];
    if (!next || next.type !== "word") continue;
    const kind = classify(next.value, segmentArgs(tokens, j + 1));
    if (kind) return kind;
  }
  return null;
}

let raw = "";
process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  try {
    const kind = destructiveKind(tokenize(raw));
    if (kind) process.stdout.write(kind);
  } catch {
    // degrade to empty output
  }
});
