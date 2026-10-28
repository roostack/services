#!/usr/bin/env bash
# Checks the copies in web/roostack/ against the Roostack commit
# web/roostack/SYNCED names, fetching each file from GitHub (Roostack is
# public), so CI needs no Roostack checkout. Fails when one differs or is
# missing; to change them, run tools/sync-roostack.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
synced=web/roostack/SYNCED
commit=$(sed -n 's/^commit //p' "$synced")
[[ $commit =~ ^[0-9a-f]{40}$ ]] || { echo "$synced names no commit" >&2; exit 1; }
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
bad=0
while IFS= read -r line; do
	[[ $line == *=* && $line != \#* ]] || continue
	out=web/roostack/${line%%=*} src=${line#*=}
	curl -fsSL --retry 3 -o "$tmp" "https://raw.githubusercontent.com/roostack/roostack/$commit/$src" ||
		{ echo "$src isn't in Roostack $commit" >&2; bad=1; continue; }
	if ! cmp -s "$tmp" "$out"; then
		echo "$out isn't Roostack $commit's $src: run tools/sync-roostack.sh" >&2
		bad=1
	fi
done < "$synced"
[[ $bad == 0 ]] && echo "web/roostack/ matches Roostack $commit"
exit $bad
