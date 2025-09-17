#!/usr/bin/env bash
# used by lintfix.yml workflow
# intended to be run in the context of the root directory of the repo

set -o errexit
set -o nounset
set -o xtrace
set -o pipefail

# set -euxo pipefail is short for:
# set -e, -o errexit: stop the script when an error occurs
# set -u, -o nounset: detects uninitialised variables in your script and exits with an error (including Env variables)
# set -x, -o xtrace: prints every expression before executing it
# set -o pipefail: If any command in a pipeline fails, use that return code for whole pipeline instead of final success


git config --global user.name "${CI_COMMIT_AUTHOR}"
git config --global user.email "${CI_COMMIT_EMAIL }"
if [[ $(git status --porcelain --untracked-files=no) ]]; then
  # Changes
  git add -A
  git commit -m "${CI_COMMIT_MESSAGE }"
  git push
else
  # No changes
  echo "no changes"
  exit 0
fi
