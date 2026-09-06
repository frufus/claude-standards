// Reads a raw shell command line on stdin and writes the commit subject
// implied by a `git commit` invocation on stdout — or nothing, when the
// command is not a commit, or the message is not visible in the command
// string at all (a heredoc / `-F -` / `--file` invocation).
//
// Hooks must never fail on unexpected input: a shape this script did not
// expect has to degrade to empty output, not to a stack trace that Claude
// Code surfaces as a broken hook. So every failure path here ends in no
// output and exit code 0 (node's default when nothing throws).
const { tokenize, isCommandStart } = require("./tokenize.js");

// Pulls the message value out of a `git commit`'s argument words, or
// returns null when no message is present in the command string (`-F`,
// `--file`, or no message flag at all).
function extractMessage(argWords) {
  for (let j = 0; j < argWords.length; j++) {
    const a = argWords[j];
    if (a === "-m" || a === "--message") {
      return j + 1 < argWords.length ? argWords[j + 1] : null;
    }
    if (a.startsWith("--message=")) return a.slice("--message=".length);
    if (a.startsWith("-m=")) return a.slice("-m=".length);
    // A short-option cluster ending in `m` (e.g. -am, -sm, -asm) takes
    // its value as the next token, same as plain -m.
    if (/^-[a-zA-Z]*m$/.test(a) && a !== "-m") {
      return j + 1 < argWords.length ? argWords[j + 1] : null;
    }
  }
  return null;
}

// Finds the first `git commit` invocation at a command position and
// returns its message, or null when there is none to judge.
function findCommitSubject(tokens) {
  for (let idx = 0; idx < tokens.length; idx++) {
    const t = tokens[idx];
    if (t.type !== "word" || t.value !== "git") continue;
    if (!isCommandStart(tokens, idx)) continue;
    const next = tokens[idx + 1];
    if (!next || next.type !== "word" || next.value !== "commit") continue;

    const argWords = [];
    let j = idx + 2;
    while (j < tokens.length && tokens[j].type === "word") {
      argWords.push(tokens[j].value);
      j++;
    }
    const message = extractMessage(argWords);
    // Git's subject is the first line of the message; everything after the
    // blank line is the body. Returning the whole message reported a
    // well-formed commit - a short subject with a long body in one -m - as a
    // subject of a hundred and fifty characters.
    if (message !== null) return message.split(String.fromCharCode(10), 1)[0].replace(new RegExp(String.fromCharCode(13) + "$"), "");
    // This invocation had no visible message (e.g. `-F -`); keep
    // scanning in case a later command in the same line is a commit
    // with one.
  }
  return null;
}

let raw = "";
process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  try {
    const subject = findCommitSubject(tokenize(raw));
    if (typeof subject === "string") process.stdout.write(subject);
  } catch {
    // degrade to empty output
  }
});
