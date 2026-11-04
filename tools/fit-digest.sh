#!/usr/bin/env bash
# Cuts the weekly security digest (Watch, on Mondays) to fit in an issue,
# which GitHub limits to 65,536 characters: the digest of 2026-11-02 had
# 2,888 matches (1.2 MB), so its issue was refused and Watch failed. It
# keeps the digest's start and as many whole matches as fit (the digest
# lists the likeliest to be exploited first), then says how many it left
# out and links the state they're all in.
#
#   tools/fit-digest.sh digest.md <link to watch/state.json> > issue.md
set -euo pipefail
digest=$1 state=$2
# Bytes, not characters, so a digest with non-ASCII text stays under too,
# with room for the last line.
LC_ALL=C awk -v max=64000 -v state="$state" '
	function flush() {
		if (item == "") return
		if (!full && size + length(item) <= max) { printf "%s", item; size += length(item) }
		else { full = 1; left++ }
		item = ""
	}
	/^- \*\*/ { flush() }
	/^- \*\*/ || item != "" { item = item $0 "\n"; next }
	{ printf "%s\n", $0; size += length($0) + 1 }
	END {
		flush()
		if (left) printf "\n%d more weaker %s didn'\''t fit in this issue. All of them are under `pending` in [watch/state.json as it was before this digest](%s).\n", left, (left == 1 ? "match" : "matches"), state
	}
' "$digest"
