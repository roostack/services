#!/usr/bin/env bash
# Says which of the update bot's pull requests are stuck (Roostack's
# docs/REGISTRY-UPDATES.md): one whose update test failed, or one that has
# waited for a person for more than three days (a minor or a major, a
# community package's, or one auto-merge left alone).
#
#   .github/stuck-updates.sh notify   # each one once, to ntfy (the Updates workflow)
#   .github/stuck-updates.sh digest   # markdown for the weekly digest (Watch)
#
# notify pushes each stuck update once to NTFY_URL, if set, and labels it
# ("stuck: test failed" or "stuck: waiting") so it isn't pushed again;
# a label someone removes lets it be pushed again later. Needs gh, with
# GH_TOKEN allowed to label pull requests.
set -euo pipefail
mode=${1:?notify or digest}
days=3

# Each open update: number, title, address, labels, age in days, and
# whether its update test failed.
updates() {
	gh pr list --state open --label update --limit 100 --json number,title,url,labels,createdAt |
		jq -c --argjson now "$(date +%s)" '.[] | {number, title, url,
			labels: [.labels[].name], age: (($now - (.createdAt | fromdateiso8601)) / 86400 | floor)}' |
		while read -r pr; do
			n=$(jq -r .number <<<"$pr")
			failed=$(gh pr checks "$n" --json name,bucket --jq '[.[] | select(.name == "test" and .bucket == "fail")] | length > 0' 2>/dev/null || echo false)
			jq -c --argjson failed "$failed" '. + {failed: $failed}' <<<"$pr"
		done
}

case $mode in
notify)
	gh label create "stuck: test failed" --color d93f0b --description "Its update test failed" --force >/dev/null 2>&1 || true
	gh label create "stuck: waiting" --color fbca04 --description "Waiting for a person for more than $days days" --force >/dev/null 2>&1 || true
	updates | while read -r pr; do
		n=$(jq -r .number <<<"$pr") url=$(jq -r .url <<<"$pr") title=$(jq -r .title <<<"$pr")
		label="" why=""
		if [ "$(jq -r .failed <<<"$pr")" = true ]; then
			label="stuck: test failed" why="Its update test failed: look at why before it can merge."
		elif [ "$(jq -r .age <<<"$pr")" -gt "$days" ]; then
			label="stuck: waiting" why="It has waited for a person for $(jq -r .age <<<"$pr") days."
		fi
		[ -n "$label" ] || continue
		jq -e --arg l "$label" '.labels | index($l)' <<<"$pr" >/dev/null && continue
		gh pr edit "$n" --add-label "$label"
		echo "$title: $why"
		if [ -n "${NTFY_URL:-}" ]; then
			curl -fsS -H "Title: Roostack: an update is stuck" -H "Click: $url" -d "$title. $why" "$NTFY_URL" >/dev/null
		fi
	done
	;;
digest)
	updates | jq -rs --argjson days "$days" '
		map(select(.failed or .age > $days)) | sort_by(-.age) |
		if length == 0 then empty else
			"\n## Updates waiting for a person\n\n" +
			(map("- **[\(.title)](\(.url))**: " +
				(if .failed then "its update test failed" else "waiting for \(.age) days" end) +
				(if (.labels | index("security")) then ", and it fixes a known security problem" else "" end) + ".") | join("\n")) + "\n"
		end'
	;;
*)
	echo "notify or digest" >&2
	exit 2
	;;
esac
