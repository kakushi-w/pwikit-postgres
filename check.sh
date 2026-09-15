#!/bin/sh
set -eu

. ./postgres.env
major=${PG_VERSION%%.*}
minor=${PG_VERSION#*.}
repo=${GITHUB_REPOSITORY:-kakushi-w/pwikit-postgres}

feed=$(curl -fsSL https://www.postgresql.org/versions.json)
latest_minor=$(printf '%s' "$feed" | jq -r --arg major "$major" '.[] | select(.major == $major) | .latestMinor')
current_major=$(printf '%s' "$feed" | jq -r '[.[] | select(.current) | .major] | first')

report() {
  title=$1
  body=$2
  if [ -n "${DRY_RUN:-}" ]; then
    printf '== %s\n%s\n' "$title" "$body"
    return
  fi
  if gh issue list --repo "$repo" --state all --search "\"$title\" in:title" --json title --jq '.[].title' | grep -qxF "$title"; then
    echo "already reported: $title"
    return
  fi
  gh issue create --repo "$repo" --title "$title" --body "$body"
}

if [ -n "$latest_minor" ] && [ "$latest_minor" -gt "$minor" ]; then
  version="$major.$latest_minor"
  sha=$(curl -fsSL "https://ftp.postgresql.org/pub/source/v$version/postgresql-$version.tar.bz2.sha256" | cut -d' ' -f1)
  if curl -fsSL "https://repo1.maven.org/maven2/io/zonky/test/postgres/embedded-postgres-binaries-windows-amd64/maven-metadata.xml" | grep -qF "<version>$version.0</version>"; then
    zonky="published"
  else
    zonky="not published yet"
  fi
  report "PostgreSQL $version is out" "PostgreSQL $version was released. This repository still builds $PG_VERSION.

Source sha256: \`$sha\`
zonky $version.0, which pwikit uses for Windows and macOS: $zonky

To update:
1. In \`postgres.env\`, set \`PG_VERSION=$version\` and \`PG_SHA256=$sha\`.
2. Commit, then tag \`$version.0-1\` and push the tag. The build workflow publishes the packages.
3. In ProjectWikit, set \`pgbundle.Version\` to \`$version.0\` and update the sha256 values in \`tools/pgarchive\`, using this release's SHA256SUMS for Linux and zonky $version.0 for Windows and macOS."
fi

if [ -n "$current_major" ] && [ "$current_major" -gt "$major" ]; then
  report "PostgreSQL $current_major is out" "PostgreSQL $current_major is now the current major release. This repository still builds $major.

Moving pwikit to a new major release changes the data directory format, so pwikit has to take its instances through a backup and restore. Keep building $major here until pwikit is ready for $current_major."
fi

echo "checked: building $PG_VERSION, latest $major.$latest_minor, current major $current_major"
