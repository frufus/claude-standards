// Reads the hook input on stdin and the filter script path as argv[2];
// writes the PreToolUse output that replaces the command with the same
// command piped through the filter. pipefail keeps the runner's exit
// status as the pipeline's; the subshell keeps the runner's own cwd and
// env untouched.
//
// `permissionDecision: allow` is what makes `updatedInput` take effect;
// the recogniser in test-command.js keeps it narrow — one bare runner
// invocation, no operator, no redirection — so nothing is allowed here
// that a team would not allow-list anyway.
const filter = process.argv[2];
let raw = "";
process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  let input;
  try { input = JSON.parse(raw); } catch { return; }
  const cmd = input && input.tool_input && input.tool_input.command;
  if (typeof cmd !== "string" || !filter) return;
  const rewritten = `set -o pipefail; ( ${cmd} ) 2>&1 | node ${JSON.stringify(filter)}`;
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      updatedInput: { ...input.tool_input, command: rewritten },
    },
  }));
});
