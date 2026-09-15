#!/bin/sh
set -eu

package=$(cd "$(dirname "${1:?usage: test.sh <package.txz>}")" && pwd)/$(basename "$1")

id tester >/dev/null 2>&1 || useradd -m tester
root=$(mktemp -d)
chmod 755 "$root"
tar -xJf "$package" -C "$root"
chown -R tester "$root"

echo "libraries outside glibc:"
outside=0
for file in $(find "$root/bin" "$root/lib" -type f); do
  for lib in $(patchelf --print-needed "$file" 2>/dev/null); do
    case "$lib" in
      libc.so.*|libm.so.*|libdl.so.*|librt.so.*|libpthread.so.*|ld-linux*) ;;
      libpq.so.*|libecpg.so.*|libecpg_compat.so.*|libpgtypes.so.*) ;;
      *) echo "  $file needs $lib"; outside=1 ;;
    esac
  done
done
[ "$outside" -eq 0 ] || exit 1
echo "  none"

newest=$(for file in $(find "$root/bin" "$root/lib" -type f); do
  objdump -T "$file" 2>/dev/null | grep -o 'GLIBC_2\.[0-9]*'
done | sort -t. -k2 -n -u | tail -1)
echo "newest glibc symbol: $newest"

su tester -s /bin/sh -c "
  set -eu
  cd '$root'
  bin/initdb -D data -U tester -E UTF8 --locale=C >/dev/null
  bin/pg_ctl -D data -o \"-k '$root' -c listen_addresses=''\" -l server.log -w start >/dev/null
  bin/psql -h '$root' -U tester -d postgres -v ON_ERROR_STOP=1 -Atc 'CREATE EXTENSION citext; CREATE EXTENSION pg_trgm; SELECT version();'
  bin/pg_ctl -D data -w stop >/dev/null
"
echo "started, loaded citext and pg_trgm, stopped"
