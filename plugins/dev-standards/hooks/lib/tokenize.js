// Tokenises a shell-ish command line, respecting single quotes, double
// quotes (with backslash escapes for `"` `\` `$` `` ` ``) and backslash
// escapes outside quotes. `&&`, `||`, `;` and `|`, and a newline outside
// quotes, are emitted as separate "op" tokens so callers can tell a real
// command boundary from plain text that happens to contain those
// characters mid-word.
//
// Shared by git-subject.js (commit subjects) and ship-command.js (push,
// PR and archive). One tokeniser, so the two hooks cannot disagree about
// what a command position is.
function tokenize(s) {
  const tokens = [];
  let word = null;
  let i = 0;
  const n = s.length;
  const flush = () => {
    if (word !== null) {
      tokens.push({ type: "word", value: word });
      word = null;
    }
  };
  while (i < n) {
    const c = s[i];
    if (word === null) {
      if (c === "\n") {
        tokens.push({ type: "op", value: "\n" });
        i++;
        continue;
      }
      if (/\s/.test(c)) {
        i++;
        continue;
      }
      if (s.startsWith("&&", i)) {
        tokens.push({ type: "op", value: "&&" });
        i += 2;
        continue;
      }
      if (s.startsWith("||", i)) {
        tokens.push({ type: "op", value: "||" });
        i += 2;
        continue;
      }
      if (c === ";" || c === "|") {
        tokens.push({ type: "op", value: c });
        i++;
        continue;
      }
      word = "";
      continue; // reprocess c now that a word has started
    }
    if (c === "\n") {
      flush();
      continue;
    }
    if (/\s/.test(c)) {
      flush();
      i++;
      continue;
    }
    if (c === "&" && s[i + 1] === "&") {
      flush();
      continue;
    }
    if (c === "|" || c === ";") {
      flush();
      continue;
    }
    if (c === "\\") {
      if (i + 1 < n) {
        word += s[i + 1];
        i += 2;
      } else {
        i++;
      }
      continue;
    }
    if (c === "'") {
      i++;
      while (i < n && s[i] !== "'") {
        word += s[i];
        i++;
      }
      i++; // consume closing quote, or run past an unterminated one
      continue;
    }
    if (c === '"') {
      i++;
      while (i < n && s[i] !== '"') {
        if (s[i] === "\\" && i + 1 < n && '"\\$`'.includes(s[i + 1])) {
          word += s[i + 1];
          i += 2;
        } else {
          word += s[i];
          i++;
        }
      }
      i++;
      continue;
    }
    word += c;
    i++;
  }
  flush();
  return tokens;
}

// A word token is at a command position when it opens the string or
// follows an operator — the same places a shell would start a new
// command. `git commit` occurring as plain text inside some other
// command's argument is not a commit.
function isCommandStart(tokens, idx) {
  return idx === 0 || tokens[idx - 1].type === "op";
}

module.exports = { tokenize, isCommandStart };
