#!/usr/bin/env bash
# Keeps one open issue saying which packages have lost the version labs
# would have been offered, because an image it pins is gone from its
# registry (Publish; Roostack's SPEC.md §8.3.3). The build still publishes,
# so nothing else would make anyone look. It's closed once none are left.
# An older version's image going needs nothing done, so it isn't listed.
#
#   .github/report-gone.sh <the log of roostack registry index>
#
# Needs gh, with GH_TOKEN allowed to write issues.
set -euo pipefail
log=${1:?the log of roostack registry index}
gh label create image-gone --color d93f0b --force >/dev/null 2>&1 || true
open=$(gh issue list --state open --label image-gone --limit 1 --json number --jq '.[0].number // empty')

gone=$(grep 'Needs a new revision or a withdrawal' "$log" | sed -e 's/^::warning:://' -e 's/^/- /' || true)
if [ -z "$gone" ]; then
	if [ -n "$open" ]; then
		gh issue close "$open" --comment "Every package has a version whose images are there again."
	fi
	exit 0
fi
body="Labs can't install these versions, because an image they pin has gone from its registry:

$gone

Check whether the project rebuilt the tag or took the release back. If it rebuilt the tag, the Updates workflow will propose a new revision within the hour. If it took the release back, withdraw the version in the package's registry.yaml and add the version to updates.yaml's ignore list."
if [ -n "$open" ]; then
	gh issue edit "$open" --body "$body"
else
	gh issue create --title "Packages whose newest image is gone" --label image-gone --body "$body"
fi
