#!/bin/sh

set -eu

branch_name=${1:-}

if [ -z "$branch_name" ]; then
    echo "usage: validate-branch-name.sh <branch>" >&2
    exit 2
fi

case "$branch_name" in
    feature/*|feat/*|fix/*|hotfix/*|refactor/*|chore/*|docs/*|test/*)
        ;;
    *)
        echo "invalid branch group: $branch_name" >&2
        exit 1
        ;;
esac

description=${branch_name#*/}

if ! printf '%s\n' "$description" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    echo "branch description must be lowercase English kebab-case: $branch_name" >&2
    exit 1
fi

if printf '%s\n' "$description" | grep -Eq '(^|-)[0-9]+(-|$)'; then
    echo "branch name must not contain a bare issue number: $branch_name" >&2
    exit 1
fi

if printf '%s\n' "$branch_name" | grep -Eiq '(^|[-/])[a-z]+-[0-9]+($|-)'; then
    echo "branch name must not contain a tracker or issue key: $branch_name" >&2
    exit 1
fi

echo "valid branch name: $branch_name"
