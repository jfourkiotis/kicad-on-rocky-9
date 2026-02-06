#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-/opt/kicad-portable}"
DEPS_PREFIX="${DEPS_PREFIX:-/opt/deps}"
JOBS="${JOBS:-$(nproc)}"
export CC="ccache gcc"
export CXX="ccache g++"
export CCACHE_DIR="${CCACHE_DIR:-/opt/ccache}"
ccache --set-config=cache_dir="${CCACHE_DIR}"
ccache --set-config=max_size=20G

SRC_DIR="${SRC_DIR:-/src}"
SRC_LOCAL="${SRC_LOCAL:-/tmp/src-local}"

mkdir -p "${DEPS_PREFIX}"

# Copy sources to container-local disk for faster builds
rm -rf "${SRC_LOCAL}"
mkdir -p "${SRC_LOCAL}"
cp -a "${SRC_DIR}/." "${SRC_LOCAL}/"
SRC_DIR="${SRC_LOCAL}"

# Build wxWidgets once
if [ ! -f "${DEPS_PREFIX}/lib/libwx_baseu-3.2.so" ]; then
  echo "Building wxWidgets..."
  WX_VER="3.2.5"
  WX_TAR="/tmp/wxWidgets-${WX_VER}.tar.bz2"
  WX_SRC="/tmp/wx-src"
  WX_BUILD="/tmp/wx-build"
  rm -rf "${WX_SRC}" "${WX_BUILD}"
  mkdir -p "${WX_SRC}" "${WX_BUILD}"
  curl -L -o "${WX_TAR}" "https://github.com/wxWidgets/wxWidgets/releases/download/v${WX_VER}/wxWidgets-${WX_VER}.tar.bz2"
  tar -xf "${WX_TAR}" -C "${WX_SRC}"
  cmake -S "${WX_SRC}/wxWidgets-${WX_VER}" -B "${WX_BUILD}" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${DEPS_PREFIX}" \
    -DwxBUILD_SHARED=ON \
    -DwxUSE_WEBVIEW=OFF
  ninja -C "${WX_BUILD}" -j"${JOBS}"
  ninja -C "${WX_BUILD}" install
fi

# Build OpenCascade once
if [ ! -f "${DEPS_PREFIX}/lib/libTKBRep.so" ] && [ ! -f "${DEPS_PREFIX}/lib64/libTKBRep.so" ] && [ ! -f "${DEPS_PREFIX}/lin64/gcc/lib/libTKBRep.so" ]; then
  echo "Building OpenCascade..."
  OCCT_VER="7_8_1"
  OCCT_TAR="/tmp/occt-${OCCT_VER}.tar.gz"
  OCCT_SRC="/tmp/occt-src"
  OCCT_BUILD="/tmp/occt-build"
  rm -rf "${OCCT_SRC}" "${OCCT_BUILD}"
  mkdir -p "${OCCT_SRC}" "${OCCT_BUILD}"
  curl -L -o "${OCCT_TAR}" "https://github.com/Open-Cascade-SAS/OCCT/archive/refs/tags/V${OCCT_VER}.tar.gz"
  tar -xf "${OCCT_TAR}" -C "${OCCT_SRC}"
  cmake -S "${OCCT_SRC}/OCCT-${OCCT_VER}" -B "${OCCT_BUILD}" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${DEPS_PREFIX}" \
    -DBUILD_LIBRARY_TYPE=Shared \
    -DUSE_FREEIMAGE=OFF \
    -DUSE_FREETYPE=ON
  ninja -C "${OCCT_BUILD}" -j"${JOBS}"
  ninja -C "${OCCT_BUILD}" install
fi

# Build ngspice once (shared lib for KiCad simulation)
if [ ! -f "${DEPS_PREFIX}/lib/libngspice.so" ] && [ ! -f "${DEPS_PREFIX}/lib64/libngspice.so" ]; then
  echo "Building ngspice..."
  # ngspice requires autoconf >= 2.70 on Rocky 9, so build a local copy
  if ! command -v autoconf >/dev/null || ! autoconf --version | head -n1 | grep -qE "2\\.(7[0-9]|[8-9][0-9])"; then
    echo "Building autoconf 2.71..."
    AUTOCONF_VER="2.71"
    AUTOCONF_TAR="/tmp/autoconf-${AUTOCONF_VER}.tar.gz"
    AUTOCONF_SRC="/tmp/autoconf-src"
    rm -rf "${AUTOCONF_SRC}"
    mkdir -p "${AUTOCONF_SRC}"
    curl -L -o "${AUTOCONF_TAR}" "https://ftp.gnu.org/gnu/autoconf/autoconf-${AUTOCONF_VER}.tar.gz"
    tar -xf "${AUTOCONF_TAR}" -C "${AUTOCONF_SRC}"
    pushd "${AUTOCONF_SRC}/autoconf-${AUTOCONF_VER}" >/dev/null
    ./configure --prefix="${DEPS_PREFIX}"
    make -j"${JOBS}"
    make install
    popd >/dev/null
    export PATH="${DEPS_PREFIX}/bin:${PATH}"
  fi
  NGSPICE_TAG="ngspice-45.2"
  NGSPICE_SRC="/tmp/ngspice-src"
  rm -rf "${NGSPICE_SRC}"
  git clone --branch "${NGSPICE_TAG}" --depth 1 git://git.code.sf.net/p/ngspice/ngspice "${NGSPICE_SRC}"
  pushd "${NGSPICE_SRC}" >/dev/null
  ./autogen.sh
  ./configure \
    --prefix="${DEPS_PREFIX}" \
    --with-ngshared \
    --enable-xspice \
    --disable-debug \
    --disable-static \
    --disable-x
  make -j"${JOBS}"
  make install
  popd >/dev/null
fi

# Build KiCad
mkdir -p /build
export PKG_CONFIG_PATH="${DEPS_PREFIX}/lib/pkgconfig:${DEPS_PREFIX}/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
OCC_LIBDIR="${DEPS_PREFIX}/lib"
if [ -f "${DEPS_PREFIX}/lib64/libTKBRep.so" ]; then
  OCC_LIBDIR="${DEPS_PREFIX}/lib64"
elif [ -f "${DEPS_PREFIX}/lin64/gcc/lib/libTKBRep.so" ]; then
  OCC_LIBDIR="${DEPS_PREFIX}/lin64/gcc/lib"
fi
cmake -S "${SRC_DIR}" -B /build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_PREFIX_PATH="${DEPS_PREFIX}" \
  -DOCC_LIBRARY_DIR="${OCC_LIBDIR}" \
  -DOCC_INCLUDE_DIR="${DEPS_PREFIX}/include/opencascade" \
  -DKICAD_USE_CMAKE_FINDPROTOBUF=ON \
  -DKICAD_USE_EGL=ON \
  -DKICAD_BUILD_QA_TESTS=OFF \
  -DKICAD_BUILD_I18N=OFF \
  -DKICAD_SPICE=ON \
  -DKICAD_SPICE_QA=OFF \
  -DKICAD_IPC_API=OFF \
  -DKICAD_SCRIPTING_WXPYTHON=OFF \
  -DKICAD_INSTALL_DEMOS=OFF

ninja -C /build -j"${JOBS}"
ninja -C /build install

# Bundle shared libs and fix RPATH
mkdir -p "${PREFIX}/lib" "${PREFIX}/lib64"

# Ensure /opt/deps shared libs are bundled even if ldd can't resolve them yet
if [ -d "${DEPS_PREFIX}/lib" ]; then
  cp -n "${DEPS_PREFIX}/lib"/*.so* "${PREFIX}/lib/" 2>/dev/null || true
fi
if [ -d "${DEPS_PREFIX}/lib64" ]; then
  cp -n "${DEPS_PREFIX}/lib64"/*.so* "${PREFIX}/lib64/" 2>/dev/null || true
fi

find_dirs=()
if [ -d "${PREFIX}/bin" ]; then
  find_dirs+=("${PREFIX}/bin")
fi
if [ -d "${PREFIX}/lib/kicad" ]; then
  find_dirs+=("${PREFIX}/lib/kicad")
fi
if [ -d "${PREFIX}/lib64/kicad" ]; then
  find_dirs+=("${PREFIX}/lib64/kicad")
fi

targets=$(find "${find_dirs[@]}" -type f -executable -o -name "*.so*")
for f in $targets; do
  file "$f" | grep -q ELF || continue
  ldd "$f" | awk "/=> \\// {print \$3}" | while read -r lib; do
    case "$lib" in
      /lib64/ld-linux*|/lib64/libc.so*|/lib64/libm.so*|/lib64/libpthread.so*|/lib64/librt.so*|/lib64/libdl.so*|/lib64/libgcc_s.so* ) continue;;
    esac
    if [[ "$lib" == /usr/lib64/* || "$lib" == /lib64/* ]]; then
      cp -n "$lib" "${PREFIX}/lib64/" || true
    else
      cp -n "$lib" "${PREFIX}/lib/" || true
    fi
  done
done

RPATH="\$ORIGIN/../lib:\$ORIGIN/../lib64:\$ORIGIN/../lib/kicad"
for f in $targets; do
  file "$f" | grep -q ELF || continue
  patchelf --set-rpath "$RPATH" "$f" || true
done
