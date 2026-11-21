#!/bin/bash
# Builds the prebuilt LLVM and CIRCT (release, with assertions) that build.sh
# downloads from the llvm-$LLVM_VERSION-circt-$CIRCT_VERSION release of
# ETHZ-DYNAMO/dynamatic-prebuilt-dependencies
set -e

# Name the tarball file using the start of the commit hash
LLVM_COMMIT=$(git -C llvm-project rev-parse HEAD)
LLVM_VERSION=${LLVM_COMMIT:0:7}
# The release tag of the CIRCT submodule without its "firtool-" prefix
CIRCT_TAG=$(git -C circt describe --tags)
CIRCT_VERSION=${CIRCT_TAG#firtool-}
WORK_DIR=$(realpath .)

cd llvm-project

# Builds and installs LLVM with the given build type, then archives the install
# directory into $WORK_DIR/$2.tar.gz
build_and_archive() {
  local BUILD_TYPE=$1
  local NAME=$2
  local INSTALL_DIR="$WORK_DIR/install-$BUILD_TYPE"

  cmake -S llvm -B "build-$BUILD_TYPE" -G Ninja \
    -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
    -DLLVM_TARGETS_TO_BUILD="host" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DLLVM_ENABLE_PROJECTS="mlir;clang;polly" \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DLLVM_EXTERNAL_PROJECTS="circt" \
    -DLLVM_EXTERNAL_CIRCT_SOURCE_DIR="$WORK_DIR/circt" \
    -DVERILATOR_DISABLE=ON \
    -DLLVM_CCACHE_BUILD=ON \
    -DLLVM_USE_LINKER=lld \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc" \
    -DLLVM_BUILD_LLVM_DYLIB=OFF \
    -DLLVM_STATIC_LINK_CXX_STDLIB=ON \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_ENABLE_LIBEDIT=OFF \
    -DLLVM_ENABLE_LIBXML2=OFF \
    -DLLVM_ENABLE_LZMA=OFF \
    -DLLVM_ENABLE_ZLIB=OFF \
    -DLLVM_ENABLE_ZSTD=OFF \
    -DLLVM_BUILD_UTILS=ON \
    -DLLVM_INCLUDE_UTILS=ON \
    -DLLVM_INSTALL_UTILS=ON

  ninja -C "build-$BUILD_TYPE" install

  # The prebuilt must not depend on external packages (e.g., LibLZMA::LibLZMA),
  # which the CMake configuration of Dynamatic fails to find where they are not
  # installed
  if grep 'INTERFACE_LINK_LIBRARIES' "$INSTALL_DIR"/lib/cmake/*/*.cmake | grep -q '::'; then
    echo "The $BUILD_TYPE prebuilt LLVM depends on an external package" >&2
    exit 1
  fi

  tar -czf "$WORK_DIR/$NAME.tar.gz" -C "$INSTALL_DIR" .
}

build_and_archive Release "llvm-$LLVM_VERSION-circt-$CIRCT_VERSION-x86_64-linux"

cd "$WORK_DIR"

ls -l "llvm-$LLVM_VERSION-circt-$CIRCT_VERSION-x86_64-linux.tar.gz"
sha256sum "llvm-$LLVM_VERSION-circt-$CIRCT_VERSION-x86_64-linux.tar.gz" > "llvm-$LLVM_VERSION-circt-$CIRCT_VERSION.sha256"
