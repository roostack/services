#!/usr/bin/env bash
# Merges an update that passed the update test (the Update test workflow),
# if it's a patch or a rebuild of an official package, or a minor that
# fixes a known security problem (roostack registry updates finds it again
# here, so the "security" label alone isn't trusted), and only once
# Publish's check has passed. Majors, and anything else, wait for a person,
# and this says why in the run's log. Run from a checkout of main.
#
#   .github/update-merge.sh ROOSTACK <pull request> <package> <version>
#
# Needs gh, with GH_TOKEN allowed to merge.
set -euo pipefail
roostack=${1:?the roostack binary} pr=${2:?pull request} pkg=${3:?package} to=${4:?version}

labels=$(gh pr view "$pr" --json labels --jq '.labels[].name')
security=false
if grep -qx 'update:minor' <<<"$labels" && grep -qx security <<<"$labels"; then
	security=true
elif ! grep -qxE 'update:(patch|revision)' <<<"$labels"; then
	echo "Waiting for a person: it isn't a patch, a rebuild, or a minor that fixes a known security problem."
	exit 0
fi
if ! grep -qx 'tier: official' "packages/$pkg/registry.yaml"; then
	echo "Waiting for a person: it isn't an official package."
	exit 0
fi

# Only if main would still propose exactly this file: an update is written
# from the newest version on main, and merging one written before a
# hand-made revision would undo that revision's changes for labs. The same
# run says again what a minor fixes (GITHUB_TOKEN, if set, for GitHub's API).
report=$("$roostack" registry updates -repo . -only "$pkg" -write)
if [ "$security" = true ] &&
	! jq -e --arg to "$to" '.updates[] | select(.to == $to) | (.fixes // []) | length > 0' <<<"$report" >/dev/null; then
	echo "Waiting for a person: it's labelled security, but no known security problem it fixes was found now."
	exit 0
fi
git fetch -q origin "pull/$pr/head"
proposed=$(git show "FETCH_HEAD:packages/$pkg/$to.yaml" | grep -v 'digests looked up')
if [ ! -f "packages/$pkg/$to.yaml" ] || [ "$(grep -v 'digests looked up' "packages/$pkg/$to.yaml")" != "$proposed" ]; then
	echo "Waiting for a person: main has changed since this update was written, so it may undo something."
	exit 0
fi
git checkout -q -- . && git clean -fdq packages

for _ in $(seq 1 40); do
	state=$(gh pr checks "$pr" --json name,bucket --jq '[.[] | select(.name == "build")][0].bucket // "pending"')
	case $state in
	pass)
		gh pr merge "$pr" --rebase --delete-branch
		exit 0
		;;
	fail | cancel)
		echo "Waiting for a person: Publish's check didn't pass."
		exit 0
		;;
	esac
	sleep 30
done
echo "Waiting for a person: Publish's check didn't finish in time."
