# pwikit-postgres

PostgreSQL builds for Linux that [ProjectWikit](https://github.com/WikitTeam/ProjectWikit) embeds in `pwikit`.

They are built in `manylinux_2_28`, so they run on glibc 2.28 and newer, and they leave out OpenSSL, ICU, readline and zlib. pwikit starts its PostgreSQL on a Unix socket with `--locale=C` and uses only `citext` and `pg_trgm`, so none of those libraries is needed, and without them the packages depend on nothing but glibc.

Windows and macOS builds come from [zonky](https://github.com/zonkyio/embedded-postgres-binaries) instead.

To build locally:

```sh
docker run --rm -v "$PWD:/src" -w /src quay.io/pypa/manylinux_2_28_x86_64 sh build.sh dist postgresql-test-linux-amd64
docker run --rm -v "$PWD:/src" -w /src quay.io/pypa/manylinux_2_28_x86_64 sh test.sh dist/postgresql-test-linux-amd64.txz
```
