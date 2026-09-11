#!/usr/bin/env node
// Status line: model, context used, session cost. Reads the JSON Claude
// Code passes on stdin and prints one line. Never fails: an empty line
// is better than a stack trace in the status bar.
//
// Fields, per the statusline reference: context_window.used_percentage,
// context_window.context_window_size, model.display_name,
// cost.total_cost_usd.
let s = "";
process.stdin.on("data", (d) => (s += d)).on("end", () => {
  let j = {};
  try { j = JSON.parse(s); } catch { /* print what we can */ }
  const cw = j.context_window || {};
  const used = Math.max(0, Math.min(100, Math.round(cw.used_percentage ?? 0)));
  const size = cw.context_window_size ? Math.round(cw.context_window_size / 1000) + "k" : "?";
  const model = (j.model && j.model.display_name) || "";
  const cost = j.cost && typeof j.cost.total_cost_usd === "number"
    ? ` · $${j.cost.total_cost_usd.toFixed(2)}` : "";
  const tenths = Math.floor(used / 10);
  const bar = "█".repeat(tenths) + "░".repeat(10 - tenths);
  process.stdout.write(`${model} · ctx ${bar} ${used}% of ${size}${cost}`);
});
