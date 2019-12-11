#!/usr/bin/bash
#
# Automatically rebase the kernel patches in ark-patches.
#
# Any patches that do not apply cleanly during the rebase are dropped, and an
# issue is filed to track rebasing that patch.
#
# This assumes you have python3-gitlab installed and a configuration file set
# up in ~/.python-gitlab.cfg or /etc/python-gitlab.cfg. An example configuration
# can be found at https://python-gitlab.readthedocs.io/en/stable/cli.html.
#
# Arguments:
#   1) The commit/tag/branch to rebase onto.
#   2) The Gitlab project ID to file issues against. See the project page on
#      Gitlab for the ID. For example, https://gitlab.com/cki-project/kernel-ark/
#      is project ID 13604247
set -e

UPSTREAM_REF=$1
PROJECT_ID=$2

ISSUE_TEMPLATE="During an automated rebase of ark-patches, commit %s failed to rebase.

The commit in question is:
~~~
%s
~~~

To fix this issue:

1. \`git rebase upstream ark-patches\`
2. Use your soft, squishy brain to resolve the conflict as you see fit. If it is
   non-trivial and has an \"Upstream Status: RHEL only\" tag, contact the author
   and ask them to rebase the patch.
3. \`if git tag -v $UPSTREAM_REF; then git branch ark/patches/$UPSTREAM_REF && git push upstream ark/patches/$UPSTREAM_REF; fi\`
4. \`git push -f upstream ark-patches\`
"

UPSTREAM="git@gitlab.com:cki-project/kernel-ark.git"
UPSTREAM_REMOTE=$(git remote -v | awk '/gitlab\.com.*cki-project\/kernel-ark\.git/ { print $1; exit }')
if [ -z "$UPSTREAM_REMOTE" ]; then
    printf "This script expects a remote named 'upstream' pointing to %s\n" "$UPSTREAM"
    printf "Run \"git remote add -f upstream %s\"\n" "$UPSTREAM"
    exit 1
fi

if git show "$UPSTREAM_REF" > /dev/null 2>&1; then
   printf "Rebasing ark-patches onto %s...\n" "$UPSTREAM_REF"
else
   printf "No such git object \"%s\" in tree\n" "$UPSTREAM_REF"
   exit 1
fi

if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" -eq "$PROJECT_ID" ] 2> /dev/null; then
    printf "Filing issues against GitLab project ID %s\n" "$PROJECT_ID"
else
    printf "No Gitlab project ID specified; halting!\n"
    exit 1
fi

CLEAN_REBASE=true
if git rebase "$UPSTREAM_REF" ark-patches; then
    printf "Cleanly rebased all patches\n"
else
    while true; do
	CLEAN_REBASE=false
	Conflict=$(git am --show-current-patch)
        Commit=$(git am --show-current-patch | head -n1 | awk '{print $2}' | cut -c 1-12)
        Title=$(printf "Unable to automatically rebase commit %s" "$Commit")
	Desc=$(printf "$ISSUE_TEMPLATE" "$Commit" "$Conflict")
        if gitlab project-issue create --project-id "$PROJECT_ID" --title "$Title" --description "$Desc" --labels "Patch Rebase"; then
            if git rebase --skip; then
                printf "Finished dropping patches that fail to rebase\n"
                break
            else
                continue
            fi
        else
            printf "Halting rebase because an issue cannot be filed for a conflict\n"
            exit 1
        fi
    done
fi

if git tag -v "$UPSTREAM_REF" && "$CLEAN_REBASE"; then
    printf "Creating branch \"ark/patches/%s\"\n" "$UPSTREAM_REF"
    git branch ark/patches/"$UPSTREAM_REF"
    git push "$UPSTREAM_REMOTE" ark/patches/"$UPSTREAM_REF"
fi

if $CLEAN_REBASE; then
	printf "Updating ark-patches..."
	git push -f "$UPSTREAM_REMOTE" ark-patches
else
	printf "Some patches could not be rebased, fix up ark-patches as necessary"
	printf " and run \"%s\"" "git push -f $UPSTREAM_REMOTE ark-patches"
	exit 2
fi
