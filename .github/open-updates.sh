#!/usr/bin/env bash
# Opens a pull request for each update roostack registry updates found and
# wrote (the Updates workflow; Roostack's docs/REGISTRY-UPDATES.md):
#
#   .github/open-updates.sh <updates.json>
#
# Run in the registry's checkout, with the new revisions written into it.
# Each update gets its own branch from main, update/<package>/<version>,
# holding only its new file. An update whose pull request someone closed is
# left alone. One whose pull request is open is left alone unless main has
# moved on and would now propose a different file (a hand-made revision the
# update would otherwise undo): then the branch is written again from main,
# which starts its checks again, unless a person has pushed to it. A branch a
# run pushed before failing, without its pull request, is opened as it is. An
# open pull request for an older update of the same package is closed,
# pointing to the new one. An update that fixes known security problems
# (its "fixes" in the report) is labelled "security", with the problems in
# its description, so it merges by itself once its test passes even when
# it's a minor (.github/update-merge.sh); one already open that turns out
# to fix one (an advisory published since) gets the label and its test is
# run again. Packages the check couldn't decide about go into the run's
# summary. Needs gh, with GH_TOKEN allowed to start workflows.
set -euo pipefail
report=${1:?the report from roostack registry updates}
summary=${GITHUB_STEP_SUMMARY:-/dev/stderr}

# The Actions bot's own address: GitHub credits a commit to the account
# its email names, and <name>@users.noreply.github.com is the account <name>.
git config user.name "Roostack updates"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
for label in update update:patch update:minor update:major update:other update:revision; do
	gh label create "$label" --color ededed --force >/dev/null 2>&1 || true
done
gh label create security --color b60205 --description "Fixes a known security problem" --force >/dev/null 2>&1 || true
existing=$(git ls-remote --heads origin 'update/*' | sed 's|.*refs/heads/||')

jq -c '.updates[]' "$report" | while read -r u; do
	pkg=$(jq -r .package <<<"$u") to=$(jq -r .to <<<"$u") kind=$(jq -r .kind <<<"$u")
	title=$(jq -r .title <<<"$u") from=$(jq -r .from <<<"$u") file=$(jq -r .file <<<"$u")
	branch="update/$pkg/$to"
	security=$(jq -r 'if (.fixes // []) | length > 0 then "yes" else "" end' <<<"$u")
	pushed=false
	open=""
	push=()
	if grep -qxF "$branch" <<<"$existing"; then
		open=$(gh pr list --state open --head "$branch" --json number --jq '.[0].number // empty')
		if [ -n "$open" ]; then
			git fetch -q --depth=1 origin "$branch"
			# The date in the comment changes with every run, and means nothing.
			if [ "$(git show "FETCH_HEAD:$file" | grep -v 'digests looked up')" = "$(grep -v 'digests looked up' "$file")" ]; then
				echo "$branch: proposed already"
				# A security problem it fixes, found since it was opened:
				# labelled, and its test run again so it can merge by itself.
				if [ -n "$security" ] && ! gh pr view "$open" --json labels --jq '.labels[].name' | grep -qx security; then
					gh pr edit "$open" --add-label security
					gh pr comment "$open" --body "$(jq -r '"This update fixes known security problems, so it will merge by itself once its test passes:\n\n" + ([.fixes[] | "- [\(.id)](\(.link)) \(.title)"] | join("\n"))' <<<"$u")"
					gh workflow run update-test.yml -f pr="$open"
					echo "$branch: fixes a security problem; labelled, and its test started again"
				fi
				continue
			fi
			if [ "$(git log -1 --format=%ae FETCH_HEAD)" != "$(git config user.email)" ]; then
				echo "$branch: main has moved on, but a person has pushed to this branch; leaving it"
				continue
			fi
			push=("--force-with-lease=refs/heads/$branch:$(git rev-parse FETCH_HEAD)")
		elif [ -n "$(gh pr list --state all --head "$branch" --json number --jq '.[].number')" ]; then
			echo "$branch: proposed already"
			continue
		else
			pushed=true
		fi
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
		(if (.fixes // []) | length > 0 then "**Fixes known security problems**, so it will merge by itself once its test passes, even as a \(.kind) update:\n\n" +
			([.fixes[] | "- [\(.id)](\(.link)) \(.title)\(if .severity then " (\(.severity))" else "" end)"] | join("\n")) + "\n\n" else "" end) +
		(if .fixes_unknown then "What it fixes couldn'\''t be looked up: \(.fixes_unknown)\n\n" else "" end) +
		"| Image | From | To |\n|---|---|---|\n" +
		([.images[] | "| \(.container) | `\(.from | sub("@sha256:(?<d>.{12}).*"; "@sha256:\(.d)…"))` | `\(.to | sub("@sha256:(?<d>.{12}).*"; "@sha256:\(.d)…"))`\(if .rebuilt then " (rebuilt)" else "" end) |"] | join("\n")) +
		"\n\nWritten by `roostack registry updates` from the newest version, \(.from): only the version and these images changed. Publish checks it like any package, and the Update test tries it on a lab."
	' <<<"$u")
	if [ "$pushed" = false ]; then
		tree="../update-$pkg"
		git worktree add -q "$tree" -B "$branch" origin/main
		mkdir -p "$tree/$(dirname "$file")"
		cp "$file" "$tree/$file"
		git -C "$tree" add "$file"
		git -C "$tree" commit -q -m "$pr_title" -m "From $from, by roostack registry updates."
		git -C "$tree" push -q "${push[@]}" origin "$branch"
		git worktree remove --force "$tree"
	else
		echo "$branch: pushed by a run that didn't open its pull request; opening it"
	fi
	labels=(--label update --label "update:$kind")
	[ -n "$security" ] && labels+=(--label security)
	if [ -n "$open" ]; then
		gh pr edit "$open" --title "$pr_title" --body "$body"
		[ -n "$security" ] && gh pr edit "$open" --add-label security
		gh pr comment "$open" --body "Main has moved on since this update was written, so it's been written again from $from."
		echo "Refreshed pull request $open"
		continue
	fi
	url=$(gh pr create --head "$branch" --title "$pr_title" --body "$body" "${labels[@]}")
	echo "Opened $url"
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
