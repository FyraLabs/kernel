#!/bin/bash

GIT_DEPTH=$1

set -x

git fetch --depth=$GIT_DEPTH origin
git checkout -b new_clog_$RANDOM origin/internal
git checkout "$CI_COMMIT_TAG" -- redhat/kernel.changelog-8.99
git add redhat/kernel.changelog-8.99
git checkout "$CI_COMMIT_TAG" -- redhat/marker
git add redhat/marker
git config user.name "CKI@GitLab"
git config user.email "cki-project@redhat.com"

# Did anything change?
LINES_CHANGED=$(git diff --cached | wc -l)
if [ "${LINES_CHANGED}" != "0" ]; then
    git commit -m "Updated changelog"
    git remote add gitlab https://oauth2:"$SECRET_KEY"@gitlab.com/jeremycline/kernel-ark.git
    git push -o merge_request.create \
                -o merge_request.target=internal \
                -o merge_request.title="Changelog Update" \
                -o merge_request.remove_source_branch \
                gitlab
fi
