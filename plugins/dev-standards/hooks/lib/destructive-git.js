// Reads a raw shell command line on stdin and writes the kind of the
// first destructive git command at a command position — `force-push`,
// `hard-reset`, `clean` or `branch-delete` — or nothing. These four are
// the shapes that destroy something the working tree cannot restore;
// everything else git does is reversible enough to stay a reminder.
//
// A guard that only recognises the canonical spelling is a guard with a
// hole: `git push -fu`, `git branch -Df`, `git push origin +main`,
// `time git clean -fd` and `GIT_TRACE=1 git reset --hard` are the same
// four shapes, and the shell accepts all of them. So a command position
// here is the start of a segment with its leading assignments and
// transparent prefixes stripped, and the flags are read as clusters.
//
// Hooks must never fail on unexpected input: every failure path ends in
// no output and exit code 0.
const { tokenize, isCommandStart } = require("./tokenize.js");

// The human's way through, honoured here rather than in the hook: a
// prefix on the segment that runs the command. Mentioning the string
// elsewhere on the line — in a commit message, say — excuses nothing.
const ALLOW = "CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1";

const ASSIGNMENT = /^[A-Za-z_][A-Za-z0-9_]*=/;

// Words a shell steps straight through on its way to the real command.
const TRANSPARENT = new Set([
  "time", "command", "exec", "env", "sudo", "nohup", "builtin",
  "!", "{", "then", "do", "else", "elif", "if", "while", "until",
]);

// `git`, `/usr/bin/git`, `git.exe` — the basename is what runs.
const GIT = /^(.*\/)?git(\.exe)?$/;

// A subshell's `(` and a group's closing `)` attach to the neighbouring
// word, because the tokeniser is shared with the reporting hooks and
// does not know about them.
function bare(word) {
  return word.replace(/^\$?\(+/, "").replace(/\)+$/, "");
}

function segmentArgs(tokens, from) {
  const args = [];
  for (let j = from; j < tokens.length && tokens[j].type === "word"; j++) args.push(bare(tokens[j].value));
  return args;
}

// `-fd`, `-Df`, `-uf`: one dash, a run of letters, any of which counts.
function cluster(arg, letter) {
  return /^-[A-Za-z]+$/.test(arg) && arg.indexOf(letter) > 0;
}

function classify(sub, args) {
  if (sub === "push" && args.some((a) =>
    a === "--force" || a.startsWith("--force-with-lease") || cluster(a, "f") || a.startsWith("+"))) return "force-push";
  if (sub === "reset" && args.includes("--hard")) return "hard-reset";
  if (sub === "clean" && args.some((a) => a === "--force" || cluster(a, "f"))) return "clean";
  if (sub === "branch") {
    if (args.some((a) => cluster(a, "D"))) return "branch-delete";
    const del = args.some((a) => a === "--delete" || cluster(a, "d"));
    const force = args.some((a) => a === "--force" || cluster(a, "f"));
    if (del && force) return "branch-delete";
  }
  return null;
}

// Global options precede the subcommand — `git -C dir reset --hard`,
// `git --no-pager push --force`, `git -c core.x=1 clean -fd` — so these
// have to be skipped before the subcommand word is read.
const GLOBAL_OPTS_WITH_VALUE = new Set(["-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env"]);

function destructiveKind(tokens) {
  for (let idx = 0; idx < tokens.length; idx++) {
    if (tokens[idx].type !== "word" || !isCommandStart(tokens, idx)) continue;

    // Walk off the front of the segment: assignments and transparent
    // prefixes, in any order, until the word that names the program.
    let j = idx;
    let allowed = false;
    while (tokens[j] && tokens[j].type === "word") {
      const word = bare(tokens[j].value);
      if (word === ALLOW) { allowed = true; j++; continue; }
      if (ASSIGNMENT.test(word) || TRANSPARENT.has(word)) { j++; continue; }
      break;
    }
    if (allowed) continue;

    const head = tokens[j];
    if (!head || head.type !== "word" || !GIT.test(bare(head.value))) continue;

    j++;
    while (tokens[j] && tokens[j].type === "word" && tokens[j].value.startsWith("-")) {
      const opt = tokens[j].value;
      j++;
      if (GLOBAL_OPTS_WITH_VALUE.has(opt)) j++;
    }
    const next = tokens[j];
    if (!next || next.type !== "word") continue;
    const kind = classify(bare(next.value), segmentArgs(tokens, j + 1));
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
