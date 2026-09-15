#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/postgres.env"
out=${1:?usage: build.sh <output directory> <package name>}
name=${2:?usage: build.sh <output directory> <package name>}
mkdir -p "$out"
out=$(cd "$out" && pwd)

dnf -q -y install flex >/dev/null

work=$(mktemp -d)
cd "$work"
source="postgresql-$PG_VERSION.tar.bz2"
curl -fsSLO "https://ftp.postgresql.org/pub/source/v$PG_VERSION/$source"
echo "$PG_SHA256  $source" | sha256sum -c -
tar -xjf "$source"
cd "postgresql-$PG_VERSION"

./configure --prefix="$work/pg" --without-icu --without-readline --without-zlib
make -s -j"$(nproc)"
make -s -C contrib -j"$(nproc)"
make -s install
make -s -C contrib install

for file in "$work/pg/bin/"* "$work/pg/lib/"lib*.so.*; do
  [ -f "$file" ] && [ ! -L "$file" ] || continue
  if patchelf --print-needed "$file" 2>/dev/null | grep -q -E '^lib(pq|ecpg|pgtypes)'; then
    case "$file" in
      "$work/pg/bin/"*) patchelf --set-rpath '$ORIGIN/../lib' "$file" ;;
      *) patchelf --set-rpath '$ORIGIN' "$file" ;;
    esac
  fi
done
rm -rf "$work/pg/include"
cp COPYRIGHT "$work/pg/COPYRIGHT"

tar -cJf "$out/$name.txz" -C "$work/pg" .
echo "wrote $out/$name.txz"
