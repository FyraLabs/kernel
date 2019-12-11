#!/bin/bash
#
# This script creates all the necessary release branches and tags. This is done
# by starting a new branch, "ark/$UPSTREAM_REF" based on the
# "ark/patches/$UPSTREAM_REF" branch which is expected to exist (see
# redhat/scripts/ark-rebase-patches.sh). The internal branch is then merged in,
# and finally "make rh-release" creates the release commit which is then tagged.
# All these references are then pushed to the upstream repository.

# Arguments:
#   1) The upstream reference to use as the base of the release. This should be
#      a tag in Linus's master branch such as v5.5-rc3 or v5.4.
set -e

UPSTREAM_REF=$1

UPSTREAM="git@gitlab.com:cki-project/kernel-ark.git"
UPSTREAM_REMOTE=$(git remote -v | awk '/gitlab\.com.*cki-project\/kernel-ark\.git/ { print $1; exit }')
if [ -z "$UPSTREAM_REMOTE" ]; then
    printf "This script expects a remote named 'upstream' pointing to %s\n" "$UPSTREAM"
    printf "Run \"git remote add -f upstream %s\"\n" "$UPSTREAM"
    exit 1
fi

# Only create release branches when rebasing onto tags, daily snapshots
# are just tagged.
if git describe --exact-match "$UPSTREAM_REF"; then
	git checkout -b ark/"$UPSTREAM_REF" ark/patches/"$UPSTREAM_REF"
else
	git checkout "$UPSTREAM_REMOTE"/ark-patches
fi

git merge -m "Merge branch 'internal' into 'ark/$UPSTREAM_REF'" internal

# Sanity check the result before tagging things
make rh-srpm

touch localversion
make rh-release
make rh-release-tag
rm localversion
if ! git describe --exact-match HEAD; then
    printf "Current HEAD is not tagged, something has gone very wrong.\n"
    exit 1
fi

git checkout master
git reset --hard ark/"$UPSTREAM_REF"
printf "Run 'git push upstream %s ark/%s ark/patches/%s %s'" "$UPSTREAM_REF" \
	"$UPSTREAM_REF" "$UPSTREAM_REF" "$(git describe --exact-match HEAD)"
printf " and 'git push -f upstream master'\n"
