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

// A spec delta is a set of `## ADDED|MODIFIED|REMOVED|RENAMED
// Requirements` sections. The requirement headings under REMOVED and
// RENAMED name requirements that are going away; they carry no scenarios
// by construction, so the unhappy-path rule does not reach them.
function sections(text) {
  const parts = text.split(/^## /m);
  const out = [{ heading: "", body: parts[0] }];
  for (const part of parts.slice(1)) {
    const nl = part.indexOf("\n");
    out.push({ heading: nl === -1 ? part : part.slice(0, nl), body: part });
  }
  return out;
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
    for (const section of sections(text)) {
      if (/REMOVED|RENAMED/i.test(section.heading)) continue;
      for (const block of section.body.split(/^### Requirement:/m).slice(1)) {
        const name = block.split(/\r?\n/)[0].trim();
        const scenarios = (block.match(/^#### Scenario:/gm) || []).length;
        if (scenarios < 2) {
          findings.push(`requirement "${name}" has ${scenarios} scenario(s); the unhappy path is missing`);
        }
      }
    }
  }

  const tasks = read(path.join(dir, "tasks.md"));
  if (tasks !== null) {
    tasks.split(/\r?\n/).forEach((line, i) => {
      if (/^\s*-\s\[[ xX]\]/.test(line) && !/(?<!un)verif/i.test(line)) {
        const title = line.replace(/^\s*-\s\[[ xX]\]\s*/, "").trim().slice(0, 60);
        // A task with no title has nothing to quote back; the line
        // number is what makes the finding findable.
        const named = title ? `task "${title}"` : `task on line ${i + 1}`;
        findings.push(`${named} does not say how it is verified`);
      }
    });
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
