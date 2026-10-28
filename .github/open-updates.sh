#!/usr/bin/env bash
# Opens a pull request for each update roostack registry updates found and
# wrote (the Updates workflow; Roostack's docs/REGISTRY-UPDATES.md):
#
#   .github/open-updates.sh <updates.json>
#
# Run in the registry's checkout, with the new revisions written into it.
# Each update gets its own branch from main, update/<package>/<version>,
# holding only its new file. An update whose branch exists already is left
# alone (it's proposed); an open pull request for an older update of the
# same package is closed, pointing to the new one. Packages the check
# couldn't decide about go into the run's summary. Needs gh, with GH_TOKEN.
set -euo pipefail
report=${1:?the report from roostack registry updates}
summary=${GITHUB_STEP_SUMMARY:-/dev/stderr}

git config user.name "Roostack updates"
git config user.email "updates@users.noreply.github.com"
for label in update update:patch update:minor update:major update:other update:revision; do
	gh label create "$label" --color ededed --force >/dev/null 2>&1 || true
done
existing=$(git ls-remote --heads origin 'update/*' | sed 's|.*refs/heads/||')

jq -c '.updates[]' "$report" | while read -r u; do
	pkg=$(jq -r .package <<<"$u") to=$(jq -r .to <<<"$u") kind=$(jq -r .kind <<<"$u")
	title=$(jq -r .title <<<"$u") from=$(jq -r .from <<<"$u") file=$(jq -r .file <<<"$u")
	branch="update/$pkg/$to"
	if grep -qxF "$branch" <<<"$existing"; then
		echo "$branch: proposed already"
		continue
	fi
	app=${to%-roostack.*}
	if [ "$kind" = revision ]; then
		pr_title="$title $to: rebuilt images"
	else
		pr_title="$title $app ($kind)"
	fi
	body=$(jq -r '
		"\(.title): \(.from) → \(.to), a **\(.kind)** update" +
		(if .kind == "revision" then " (the same version, its images rebuilt)" else "" end) + ".\n\n" +
		(if .releases then "What'\''s new: \(.releases)\n\n" else "" end) +
		"| Image | From | To |\n|---|---|---|\n" +
		([.images[] | "| \(.container) | `\(.from | sub("@sha256:(?<d>.{12}).*"; "@sha256:\(.d)…"))` | `\(.to | sub("@sha256:(?<d>.{12}).*"; "@sha256:\(.d)…"))`\(if .rebuilt then " (rebuilt)" else "" end) |"] | join("\n")) +
		"\n\nWritten by `roostack registry updates` from the newest version, \(.from): only the version and these images changed. Publish checks it like any package; nothing merges this until a person (or, later, the update test) says so."
	' <<<"$u")
	tree="../update-$pkg"
	git worktree add -q "$tree" -b "$branch" origin/main
	mkdir -p "$tree/$(dirname "$file")"
	cp "$file" "$tree/$file"
	git -C "$tree" add "$file"
	git -C "$tree" commit -q -m "$pr_title" -m "From $from, by roostack registry updates."
	git -C "$tree" push -q origin "$branch"
	url=$(gh pr create --head "$branch" --title "$pr_title" --body "$body" --label update --label "update:$kind")
	echo "Opened $url"
	git worktree remove --force "$tree"
	# An open pull request for an older update of this package is superseded.
	gh pr list --state open --json number,headRefName --jq ".[] | select(.headRefName | startswith(\"update/$pkg/\")) | select(.headRefName != \"$branch\") | .number" |
		while read -r old; do
			gh pr close "$old" --delete-branch --comment "Superseded by $url."
		done
done

if [ "$(jq '.skipped | length' "$report")" -gt 0 ]; then
	{
		echo "### Packages the update check couldn't decide about"
		echo
		jq -r '.skipped[] | "- **\(.package)**: \(.reason)"' "$report"
	} >> "$summary"
fi
