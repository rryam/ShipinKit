#!/bin/bash

set -euo pipefail

artifact_path="${1:-}"

if [[ -z "$artifact_path" || ! -f "$artifact_path" ]]; then
  echo "Expected an XCFramework zip path." >&2
  exit 1
fi

if [[ ! -s "$artifact_path" ]]; then
  echo "The XCFramework zip is empty." >&2
  exit 1
fi

for command_name in curl jq; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command is unavailable: $command_name" >&2
    exit 1
  fi
done

: "${EMERGE_API_KEY:?EMERGE_API_KEY is required}"
: "${EMERGE_BASE_SHA:?EMERGE_BASE_SHA is required}"
: "${EMERGE_BRANCH:?EMERGE_BRANCH is required}"
: "${EMERGE_REPOSITORY:?EMERGE_REPOSITORY is required}"
: "${EMERGE_SHA:?EMERGE_SHA is required}"

filename="$(basename "$artifact_path")"
request_body="$(
  jq -cn \
    --arg filename "$filename" \
    --arg branch "$EMERGE_BRANCH" \
    --arg sha "$EMERGE_SHA" \
    --arg base_sha "$EMERGE_BASE_SHA" \
    --arg repository "$EMERGE_REPOSITORY" \
    '{
      filename: $filename,
      branch: $branch,
      sha: $sha,
      baseSha: $base_sha,
      repoName: $repository,
      buildType: "release"
    }'
)"

upload_response="$(
  curl \
    --fail \
    --silent \
    --show-error \
    --retry 3 \
    --request POST \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --header "X-API-Token: $EMERGE_API_KEY" \
    --data "$request_body" \
    'https://api.emergetools.com/upload'
)"

if ! upload_url="$(jq -er '.uploadURL | select(type == "string" and length > 0)' <<<"$upload_response")"; then
  echo "Emerge did not return an upload URL." >&2
  exit 1
fi

curl \
  --fail \
  --silent \
  --show-error \
  --retry 3 \
  --request PUT \
  --header 'Content-Type: application/zip' \
  --upload-file "$artifact_path" \
  --output /dev/null \
  "$upload_url"

echo "Uploaded $filename to Emerge."
