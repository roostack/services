#!/usr/bin/env bash
# Merges an update that passed the update test (the Update test workflow),
# if it's a patch or a rebuild of an official package, and only once
# Publish's check has passed. Anything else waits for a person, and this
# says why in the run's log. Run from a checkout of main.
#
#   .github/update-merge.sh ROOSTACK <pull request> <package> <version>
#
# Needs gh, with GH_TOKEN allowed to merge.
set -euo pipefail
roostack=${1:?the roostack binary} pr=${2:?pull request} pkg=${3:?package} to=${4:?version}

labels=$(gh pr view "$pr" --json labels --jq '.labels[].name')
if ! grep -qxE 'update:(patch|revision)' <<<"$labels"; then
	echo "Waiting for a person: it isn't a patch or a rebuild."
	exit 0
fi
if ! grep -qx 'tier: official' "packages/$pkg/registry.yaml"; then
	echo "Waiting for a person: it isn't an official package."
	exit 0
fi

# Only if main would still propose exactly this file: an update is written
# from the newest version on main, and merging one written before a
# hand-made revision would undo that revision's changes for labs.
"$roostack" registry updates -repo . -only "$pkg" -write >/dev/null
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
