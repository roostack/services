#!/usr/bin/env bash
# Copies the files the registry's page (web/) takes from Roostack into
# web/roostack/, exactly as a Roostack commit has them, and names that
# commit in web/roostack/SYNCED:
#
#   tools/sync-roostack.sh <Roostack checkout> [ref]   (default ref: origin/main)
#
# The page uses Roostack's design system (its tokens, the default theme,
# app.css and the display font) and the YAML parser its package editor
# vendors. Roostack is Apache-2.0, as this repository is. CI checks the
# copies against the commit SYNCED names (tools/check-roostack.sh), so a
# copy is changed only by running this again.
set -euo pipefail
cd "$(dirname "$0")/.."
roostack=${1:?the path to a Roostack checkout}
ref=${2:-origin/main}
commit=$(git -C "$roostack" rev-parse --verify "$ref^{commit}")

# Published path under web/roostack/ = path in Roostack.
files=(
	"css/tokens.css=internal/web/static/css/tokens.css"
	"css/themes/teal.css=internal/web/static/css/themes/teal.css"
	"css/app.css=internal/web/static/css/app.css"
	"fonts/space-grotesk-latin.woff2=internal/web/static/fonts/space-grotesk-latin.woff2"
	"fonts/space-grotesk-OFL.txt=internal/web/static/fonts/space-grotesk-OFL.txt"
	"yaml-2.9.1.min.js=internal/editor/static/yaml-2.9.1.min.js"
)
rm -rf web/roostack
for f in "${files[@]}"; do
	out=web/roostack/${f%%=*}
	mkdir -p "$(dirname "$out")"
	git -C "$roostack" show "$commit:${f#*=}" > "$out"
done
{
	echo "# Copied from Roostack (https://github.com/roostack/roostack) by"
	echo "# tools/sync-roostack.sh; Apache-2.0. The commit, then each copy and its"
	echo "# path in Roostack, which tools/check-roostack.sh compares."
	echo "commit $commit"
	printf '%s\n' "${files[@]}"
} > web/roostack/SYNCED
echo "Copied ${#files[@]} files from Roostack $commit"
