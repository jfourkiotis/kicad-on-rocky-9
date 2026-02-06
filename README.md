# KiCad Portable (Rocky Linux 9)

[![build-kicad-portable](https://github.com/jfourkiotis/kicad-on-rocky-9/actions/workflows/build.yml/badge.svg)](https://github.com/jfourkiotis/kicad-on-rocky-9/actions/workflows/build.yml)

This repo builds a **relocatable** KiCad 9.0.7 bundle inside a Rocky Linux 9 Docker container and outputs a tarball:

```
out/kicad-portable-rocky9.tar.gz
```

The tarball can be extracted anywhere (for example under a user's home directory) and run without system-wide installation.

## Requirements

- Docker Desktop (Linux containers)
- Windows PowerShell

## Build locally

From the repo root:

```
docker build -t kicad-rocky9 .

docker run --name kicad-build -e PREFIX=/opt/kicad-portable ^
  -v "${repo}:/work" ^
  -v "${repo}\kicad-9.0.7\kicad-9.0.7:/src" ^
  -v "${repo}\out:/out" ^
  -v kicad_deps:/opt/deps ^
  kicad-rocky9 bash -lc "chmod +x /work/build.sh && /work/build.sh && tar -C /opt -czf /out/kicad-portable-rocky9.tar.gz kicad-portable"
```

When it finishes, the tarball will be in `out/`.

## Run on Linux workstation

Extract anywhere, e.g.:

```
mkdir -p ~/apps
cd ~/apps

tar -xf kicad-portable-rocky9.tar.gz
```

If your system loader doesn't resolve bundled libraries, use a small tcsh launcher:

```
#!/bin/tcsh
set KICAD_HOME="/path/to/kicad-portable"
if (! $?LD_LIBRARY_PATH) setenv LD_LIBRARY_PATH ""
setenv LD_LIBRARY_PATH "${KICAD_HOME}/lib:${KICAD_HOME}/lib64:${KICAD_HOME}/lib/kicad:${LD_LIBRARY_PATH}"
exec "${KICAD_HOME}/bin/kicad" "$argv"
```

Save as `kicad.csh`, `chmod +x kicad.csh`, then run `./kicad.csh`.

## Notes

- `build.sh` compiles wxWidgets, OpenCascade, and ngspice from source and bundles all libs from `/opt/deps`.
- KiCad is patched for relocatable data paths on Linux (see `common/paths.cpp`).

## GitHub Actions

A workflow is included to build and attach the tarball to a GitHub Release when you push a tag like `v9.0.7`.

