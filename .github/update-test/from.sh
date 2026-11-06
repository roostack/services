#!/usr/bin/env bash
# Says which version the update test starts from: the newest that labs can
# install now, from the published index, or nothing if there's none (the
# images of every version have gone, or it's a new package), when the test
# will start from the update itself.
#
#   .github/update-test/from.sh <package> <to>
set -euo pipefail
pkg=${1:?package} to=${2:?version}
curl -fsSL --retry 3 https://registry.roostack.cloud/v1/index.json |
	jq -r --arg pkg "$pkg" --arg to "$to" '
		.packages[$pkg].versions // {} | to_entries[]
		| select(.key != $to and (.value.image_gone | not)
			and (.value.withdrawn == null or .value.withdrawn.level == "notice"))
		| .key' |
	sort -V | tail -1
