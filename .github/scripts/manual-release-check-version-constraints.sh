#!/usr/bin/env bash
# used by manual-release.yml workflow
# intended to be run in the context of the root directory of the repo

# REQUIRED ENV VARIABLES:
# + TERRAFORM_MODULE
# + VERSION

module="${TERRAFORM_MODULE}"
new_version="${VERSION}"

set -o errexit
set -o nounset
set -o xtrace
set -o pipefail

# set -euxo pipefail is short for:
# set -e, -o errexit: stop the script when an error occurs
# set -u, -o nounset: detects uninitialised variables in your script and exits with an error (including Env variables)
# set -x, -o xtrace: prints every expression before executing it
# set -o pipefail: If any command in a pipeline fails, use that return code for whole pipeline instead of final success

tag_name="$module-v$new_version"

# Check if exact tag already exists
if git tag -l | grep -q "^$tag_name$"; then
  echo "ERROR: Tag $tag_name already exists"
  exit 1
fi

# Get latest version for this module
latest_tag=$(git tag -l "${module}-v*" | sort -V | tail -n1)

if [ -n "$latest_tag" ]; then
  latest_version=${latest_tag#${module}-v}
  echo "Latest existing version: $latest_version"
  echo "New version: $new_version"

  # Compare versions using sort -V (version sort)
  higher_version=$(echo -e "$latest_version\n$new_version" | sort -V | tail -n1)

  if [ "$higher_version" = "$latest_version" ] && [ "$new_version" != "$latest_version" ]; then
    echo "ERROR: New version $new_version is not greater than latest version $latest_version"
    echo "Next valid versions would be:"

    # Suggest next versions
    IFS='.' read -r major minor patch <<< "$latest_version"
    echo "   - Patch: $major.$minor.$((patch + 1))"
    echo "   - Minor: $major.$((minor + 1)).0"
    echo "   - Major: $((major + 1)).0.0"
    exit 1
  fi
else
  echo "No existing versions found for module $module"
fi

echo "Version $new_version is valid and available"
