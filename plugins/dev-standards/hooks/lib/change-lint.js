// Takes a change directory and prints one line per rule of the shared
// config.rules.yaml the change breaks — the three that are structural
// enough to check: a proposal names its Non-Goals, every requirement has
// at least two scenarios (the rule asks for an unhappy path, and two is
// what following it produces), and every task says how it is verified.
//
// Reports only; the ship check turns these lines into a reminder. A
// missing file is not a finding here — the change may be half-written,
// and other checks own that. Anything unreadable degrades to no output
// and exit 0, like every helper in this directory.
const fs = require("fs");
const path = require("path");

function read(file) {
  try {
    return fs.readFileSync(file, "utf8");
  } catch {
    return null;
  }
}

function specFiles(dir) {
  let found = [];
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return found;
  }
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) found = found.concat(specFiles(full));
    else if (entry.name === "spec.md") found.push(full);
  }
  return found;
}

function lint(dir) {
  const findings = [];

  const proposal = read(path.join(dir, "proposal.md"));
  if (proposal !== null && !/^#{1,6}\s.*Non-Goals/im.test(proposal)) {
    findings.push("proposal.md has no Non-Goals section");
  }

  for (const file of specFiles(path.join(dir, "specs"))) {
    const text = read(file);
    if (text === null) continue;
    for (const block of text.split(/^### Requirement:/m).slice(1)) {
      const name = block.split(/\r?\n/)[0].trim();
      const scenarios = (block.match(/^#### Scenario:/gm) || []).length;
      if (scenarios < 2) {
        findings.push(`requirement "${name}" has ${scenarios} scenario(s); the unhappy path is missing`);
      }
    }
  }

  const tasks = read(path.join(dir, "tasks.md"));
  if (tasks !== null) {
    for (const line of tasks.split(/\r?\n/)) {
      if (/^\s*-\s\[[ xX]\]/.test(line) && !/(?<!un)verif/i.test(line)) {
        const title = line.replace(/^\s*-\s\[[ xX]\]\s*/, "").slice(0, 60);
        findings.push(`task "${title}" does not say how it is verified`);
      }
    }
  }

  return findings;
}

try {
  const dir = process.argv[2];
  if (dir) {
    const findings = lint(dir);
    if (findings.length) process.stdout.write(findings.join("\n") + "\n");
  }
} catch {
  // degrade to no output
}
