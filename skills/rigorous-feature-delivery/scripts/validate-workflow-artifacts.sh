#!/bin/sh

set -eu

base_ref=${1:-}
head_ref=${2:-HEAD}

if [ -z "$base_ref" ]; then
    echo "usage: validate-workflow-artifacts.sh <base> [head]" >&2
    exit 2
fi

changed_files=$(git diff --name-only --diff-filter=ACMRTUXB "$base_ref..$head_ref")
workflow_files=$(printf '%s\n' "$changed_files" | grep -Ei '(^|/)(docs/superpowers/(plans|specs)/.*\.md|[^/]*(plan|progress|tracker|handoff|evidence)([-_.][^/]*)?\.md|[^/]*(计划|进度|追踪|交接|证据)[^/]*\.md)$' || true)

if [ -n "$workflow_files" ]; then
    echo "workflow Markdown must not be committed:" >&2
    printf '%s\n' "$workflow_files" >&2
    exit 1
fi

echo "no committed workflow Markdown found in $base_ref..$head_ref"
