#!/usr/bin/env bash

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
TEST_DIR="$DIR/../tests"

failed_tests=()
for test in "$TEST_DIR"/*.jsonnet; do
    filename=$(basename -- "$test")
    filename="${filename%.*}"
    snapshot="$(dirname "$test")/$filename.snap"
    result=$(mktemp)
    kubecfg \
    --jurl http://k8s-clusters.outreach.cloud/ \
    --jurl https://raw.githubusercontent.com/getoutreach/jsonnet-libs/master \
    --jpath "$DIR/../" \
    -V environment=development \
    show "$test" > "$result"

    
    if ! diff "$snapshot" "$result" >/dev/null 2>&1; then
        failed_tests+=("$filename")
    fi

    cat "$result" > "$snapshot"
done

if (( ${#failed_tests[@]} )); then
    >&2 echo "snapshots did not match and were updated: ${failed_tests[*]}"
    exit 1
fi
