. plugins/dev-standards/hooks/lib/paths.sh 2>/dev/null

check "strips the root and normalises separators" \
  "$(rel_path 'C:\proj\src\a.ts' 'C:\proj')" "src/a.ts"
check "tolerates a case-mismatched root" \
  "$(rel_path 'C:\Proj\Src\A.ts' 'c:/proj')" "src/a.ts"
check "a file outside the root stays absolute" \
  "$(rel_path 'D:\other\a.ts' 'C:\proj')" "d:/other/a.ts"

is_source_path "src/a.ts";            check "src is source" "$?" "0"
is_source_path "main.py";             check "a root module is source" "$?" "0"
is_source_path "backend/app/db.py";   check "nested source is source" "$?" "0"
is_source_path "openspec/config.yaml";check "openspec is excluded" "$?" "1"
is_source_path "docs/adr/0001-x.md";  check "docs is excluded" "$?" "1"
is_source_path ".claude/settings.json";check ".claude is excluded" "$?" "1"
is_source_path ".gitignore";          check "root dotfile is excluded" "$?" "1"
is_source_path "src/.env";            check "nested dotfile is excluded" "$?" "1"
is_source_path "package-lock.json";   check "npm lockfile is excluded" "$?" "1"
is_source_path "uv.lock";             check "uv lockfile is excluded" "$?" "1"

# The ship check needs the project root without calling openspec, so it
# walks up from cwd to the nearest directory holding openspec/.
root=$(mktemp -d)
mkdir -p "$root/openspec" "$root/src/deep"
check "finds openspec in the directory itself" "$(os_root_of "$root")" "$root"
check "finds openspec above a nested cwd"      "$(os_root_of "$root/src/deep")" "$root"
check "normalises backslashes"                 "$(os_root_of "${root//\//\\}/src")" "$root"
none=$(mktemp -d)
check "finds nothing where there is nothing"   "$(os_root_of "$none")" ""
check "a missing directory yields nothing"     "$(os_root_of "/definitely/not/here")" ""
rm -rf "$root" "$none"
