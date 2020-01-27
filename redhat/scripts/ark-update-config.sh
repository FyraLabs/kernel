#!/bin/bash

# The treeish object to update internal to
UPDATE_TO=$1

git checkout internal
git pull
git merge -m "Merge '$UPDATE_TO' into 'internal'" "$UPDATE_TO"
if git show -s --oneline HEAD | grep -q "AUTOMATIC: New configs"; then
    make rh-configs-commit
    git push upstream internal
    ./redhat/gen_config_patches.sh
    for branch in $(git branch | grep configs/"$(date +%F)"); do
        git push \
            -o merge_request.create \
            -o merge_request.target=internal \
            -o merge_request.remove_source_branch \
            -o merge_request.label="Configuration" \
            upstream "$branch"
    done
else
    printf "No new configuration values exposed from merging %s into internal\n" "$UPDATE_TO"
    git push upstream internal
fi
