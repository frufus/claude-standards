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
check "plugin version is 0.2.0" \
  "$(node -p 'require("./plugins/dev-standards/.claude-plugin/plugin.json").version' 2>/dev/null)" "0.2.0"
contains "plugin description names verification" \
  "$(node -p 'require("./plugins/dev-standards/.claude-plugin/plugin.json").description' 2>/dev/null)" "verif"
contains "marketplace description names verification" \
  "$(node -p 'require("./.claude-plugin/marketplace.json").plugins[0].description' 2>/dev/null)" "verif"

readme=$(cat README.md 2>/dev/null)
contains "README counts five skills"          "$readme" "Five skills"
contains "README counts four hooks"           "$readme" "Four hooks"
contains "README documents the verify skill"  "$readme" "\`verify\`"
contains "README documents the scripts"       "$readme" "scripts/verify"
contains "README documents progress.md"       "$readme" "progress.md"
contains "README documents the ship check"    "$readme" "verification.md"
