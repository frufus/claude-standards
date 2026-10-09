# Manifests must parse and carry the fields Claude Code requires to load
# the plugin. A malformed manifest fails silently at load time — the
# plugin simply does not appear — so it is worth asserting here.
MARKET=".claude-plugin/marketplace.json"
PLUGIN="plugins/dev-standards/.claude-plugin/plugin.json"

check "marketplace parses" \
  "$(node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log("ok")' "$MARKET" 2>/dev/null)" "ok"
check "marketplace name" \
  "$(node -p 'require("./.claude-plugin/marketplace.json").name' 2>/dev/null)" "claude-standards"
check "marketplace lists the plugin" \
  "$(node -p 'require("./.claude-plugin/marketplace.json").plugins[0].name' 2>/dev/null)" "dev-standards"
check "plugin source is the proven relative form" \
  "$(node -p 'require("./.claude-plugin/marketplace.json").plugins[0].source' 2>/dev/null)" "./plugins/dev-standards"
check "plugin manifest parses" \
  "$(node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log("ok")' "$PLUGIN" 2>/dev/null)" "ok"
check "plugin name matches marketplace entry" \
  "$(node -p 'require("./plugins/dev-standards/.claude-plugin/plugin.json").name' 2>/dev/null)" "dev-standards"
check "plugin version is 0.4.0" \
  "$(node -p 'require("./plugins/dev-standards/.claude-plugin/plugin.json").version' 2>/dev/null)" "0.4.0"
contains "plugin description names verification" \
  "$(node -p 'require("./plugins/dev-standards/.claude-plugin/plugin.json").description' 2>/dev/null)" "verif"
contains "marketplace description names verification" \
  "$(node -p 'require("./.claude-plugin/marketplace.json").plugins[0].description' 2>/dev/null)" "verif"

readme=$(cat README.md 2>/dev/null)
contains "README counts five skills"          "$readme" "Five skills"
contains "README counts six hooks"            "$readme" "Six hooks"
contains "README documents the hook review"   "$readme" "Before a hook runs"
contains "README documents the global layer install" "$readme" "statusline.js"
contains "README documents the measurement doc" "$readme" "token-measurement.md"
contains "README documents the model pins"    "$readme" "ADR-0005"
contains "README documents the effort floor"  "$readme" "ADR-0006"
not_contains "README no longer claims medium effort" "$readme" "effort to \`medium\`"
contains "README documents the verify skill"  "$readme" "\`verify\`"
contains "README documents the scripts"       "$readme" "scripts/verify"
contains "README documents progress.md"       "$readme" "progress.md"
contains "README documents the ship check"    "$readme" "verification.md"
contains "README documents AGENTS.md"         "$readme" "AGENTS.md"
contains "README documents the PR contract"   "$readme" "pull_request_template"
contains "README documents the compound step" "$readme" "compound"
contains "README documents the proposal lint" "$readme" "Non-Goals"
contains "README documents the tag"           "$readme" "v0.4.0"
contains "README documents the fitness step"  "$readme" "fitness check"

# "Releases are tagged" is not an instruction. Both routes to a pinned
# install are spelled out, because a tag nobody can check out is a
# version number in a file.
contains "README names the local checkout route"    "$readme" 'marketplace add C:\Users\frufus\development\claude-standards'
contains "README names the marketplace cache route" "$readme" "~/.claude/plugins/marketplaces/claude-standards"
contains "README says to check the tag out"         "$readme" "git checkout v0.4.0"

# The hooks table is what a reader consults instead of reading the hook.
srow=$(grep -F '| `SessionStart`' README.md 2>/dev/null)
contains "README's SessionStart row names AGENTS.md"      "$srow" "AGENTS.md"
contains "README's SessionStart row names scripts/verify" "$srow" "scripts/verify"
not_contains "README does not miscount the helper libraries" "$readme" "both helper libraries"

contains "plugin description names AGENTS.md" \
  "$(node -p 'require("./plugins/dev-standards/.claude-plugin/plugin.json").description' 2>/dev/null)" "AGENTS.md"
