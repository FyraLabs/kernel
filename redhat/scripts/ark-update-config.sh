#!/bin/bash
#
# This script is intended to regularly update the internal branch with the latest
# configuration options from upstream. It merges the given reference into
# internal, adds all new configuration symbols to the pending/ config directory,
# and opens a merge request for each configuration change so maintainers can
# review each setting.
#
# This script assumes the repository contains two remotes:
#   * linus - this should be Linus's tree.
#   * upstream - this should be the ARK upstream repository.
#
# If the upstream branch fails to merge an issue is filed against the provided
# project ID.
#
# Arguments:
#   1) The git object to merge into internal. This should be something from
#	Linus's master branch, usually either a tag such as v5.5-rc3 or just
#	linus/master.
#   2) The Gitlab project ID to file issues against. See the project page on
#	Gitlab for the ID. For example, https://gitlab.com/cki-project/kernel-ark/
#	is project ID 13604247
set -e

UPSTREAM_REF=$1
PROJECT_ID=$2

UPSTREAM="git@gitlab.com:cki-project/kernel-ark.git"
UPSTREAM_REMOTE=$(git remote -v | awk '/gitlab\.com.*cki-project\/kernel-ark\.git/ { print $1; exit }')
if [ -z "$UPSTREAM_REMOTE" ]; then
    printf "This script expects a remote pointing to %s\n" "$UPSTREAM"
    printf "Run \"git remote add -f upstream %s\"\n" "$UPSTREAM"
    exit 1
fi
LINUS="git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
LINUS_REMOTE=$(git remote -v | awk '/kernel.org.*torvalds\/linux\.git/ { print $1; exit }')
if [ -z "$LINUS_REMOTE" ]; then
    printf "This script expects a remote pointing to %s\n" "$LINUS"
    printf "Run \"git remote add -f linus %s\"\n" "$LINUS"
    exit 1
fi

if ! git branch -r --contains "$UPSTREAM_REF" | grep -q "$LINUS_REMOTE/master"; then
	printf "Error: Only merge $LINUS_REMOTE/master or an upstream tag into internal!\n"
	exit 1
fi

git checkout internal
git pull
if git branch -r --contains "$UPSTREAM_REF" | grep -q "internal"; then
	printf "The 'internal' branch already contains %s: nothing to do.\n" "$UPSTREAM_REF"
	exit 0
fi

if ! git merge -m "Merge '$UPSTREAM_REF' into 'internal'" "$UPSTREAM_REF"; then
	git merge --abort
	printf "Merge conflict; halting!\n"
	Issues=$(gitlab project-issue list --state "opened" --labels "Configuration Update" --project-id "$PROJECT_ID")
	if [ -z "$Issues" ]; then
		gitlab project-issue create --project-id "$PROJECT_ID" \
			--title "Merge conflict between '$UPSTREAM_REF' and 'internal'" \
			--labels "Configuration Update" \
			--description "A merge conflict has occurred and must be resolved manually."
	fi
	exit 1
fi

make FLAVOR=fedora rh-configs-commit
make rh-configs-commit

# Hack alter: Fedora carries a patch to alter this setting, so the config is only
# valid with the patch set. Set it back to the vanilla default and check that
# that the config is valid. Often configuration switches states (from tristate
# to bool, for example) and becomes invalid, requiring a bit of manual intervention.
sed -i 's/=13/=11/g' redhat/configs/fedora/generic/arm/aarch64/CONFIG_FORCE_MAX_ZONEORDER
if ! make rh-srpm; then
	printf "Failed to generate an SRPM; halting!\n"
	Issues=$(gitlab project-issue list --state "opened" --labels "Configuration Update" --project-id "$PROJECT_ID")
	if [ -z "$Issues" ]; then
		gitlab project-issue create --project-id "$PROJECT_ID" \
			--title "Unable to generate SRPM with the auto-generated default configs" \
			--labels "Configuration Update" \
			--description "After merging $UPSTREAM_REF into internal \
			and running \"make rh-configs-commit\", \"make rh-srpm\" \
			failed. This needs to be fixed manually by running \
			redhat/scripts/ark-update-config.sh and adjusting the \
			\"AUTOMATIC: New configs\" commit. If settings in common \
			or ark change, move them back to pending-common and \
			submit them for review."
	fi
	exit 1
fi
git checkout -- redhat/configs/fedora/generic/arm/aarch64/CONFIG_FORCE_MAX_ZONEORDER

if git show -s --oneline HEAD | grep -q "AUTOMATIC: New configs"; then
	./redhat/gen_config_patches.sh
	git push "$UPSTREAM_REMOTE" internal
	for branch in $(git branch | grep configs/"$(date +%F)"); do
		if [ "$(git log internal.."$branch" --pretty=oneline | wc -l)" -ne 1 ]; then
			printf "More than one commit in %s, something went wrong in patch generation!\n" "$branch"
			exit 1
		fi
		git push \
			-o merge_request.create \
			-o merge_request.target=internal \
			-o merge_request.remove_source_branch \
			-o merge_request.label="Configuration" \
			"$UPSTREAM_REMOTE" "$branch"
	done
else
	printf "No new configuration values exposed from merging %s into internal\n" "$UPSTREAM_REF"
	git push "$UPSTREAM_REMOTE" internal
fi
