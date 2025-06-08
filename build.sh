#!/bin/bash

# Build nano for MIPS little-endian architecture (Creality 3D printers)
# Tested on Debian 12 (bookworm)

set -e  # Exit on any error

# Configuration
WORKSPACE="/tmp/mips-build"
SYSROOT="${WORKSPACE}/mips-sysroot"
NCURSES_VERSION="6.4"
NANO_VERSION="7.2"

echo "=== Building nano for MIPS little-endian architecture ==="

# Install required packages
echo "Installing build dependencies..."
apt update
apt install -y gcc-mipsel-linux-gnu g++-mipsel-linux-gnu wget build-essential texinfo

# Create workspace
echo "Creating workspace at ${WORKSPACE}..."
mkdir -p "${WORKSPACE}"
cd "${WORKSPACE}"

# Build ncurses library
echo "Building ncurses ${NCURSES_VERSION} for MIPS little-endian..."
if [ ! -f "ncurses-${NCURSES_VERSION}.tar.gz" ]; then
    wget "https://ftp.gnu.org/gnu/ncurses/ncurses-${NCURSES_VERSION}.tar.gz"
fi

tar -xzf "ncurses-${NCURSES_VERSION}.tar.gz"
cd "ncurses-${NCURSES_VERSION}"

./configure \
    --host=mipsel-linux-gnu \
    --prefix="${SYSROOT}" \
    --enable-static \
    --disable-shared \
    --without-debug \
    --without-tests \
    --without-cxx-binding \
    --with-normal \
    --disable-widec \
    --with-fallbacks=linux,screen,vt100,xterm \
    CC=mipsel-linux-gnu-gcc

make -j$(nproc)
make install

# Fix ncurses header structure
echo "Fixing ncurses header paths..."
cd "${SYSROOT}/include/ncurses"
mkdir -p ncurses
for f in *.h; do
    ln -sf ../$f ncurses/$f
done

# Build nano
echo "Building nano ${NANO_VERSION}..."
cd "${WORKSPACE}"
if [ ! -f "nano-${NANO_VERSION}.tar.xz" ]; then
    wget "https://www.nano-editor.org/dist/v7/nano-${NANO_VERSION}.tar.xz"
fi

tar -xf "nano-${NANO_VERSION}.tar.xz"
cd "nano-${NANO_VERSION}"

PKG_CONFIG_PATH="${SYSROOT}/lib/pkgconfig" \
./configure \
    --host=mipsel-linux-gnu \
    --prefix=/usr/local \
    --disable-nls \
    --disable-utf8 \
    --enable-tiny \
    CC=mipsel-linux-gnu-gcc \
    CPPFLAGS="-I${SYSROOT}/include/ncurses" \
    LDFLAGS="-L${SYSROOT}/lib -static"

make -j$(nproc)

# Copy final binary
echo "Copying final binary..."
cp src/nano "${WORKSPACE}/nano-mipsel"

echo "=== Build complete! ==="
echo "Binary location: ${WORKSPACE}/nano-mipsel"
echo ""
echo "To install on your MIPS device:"
echo "1. Copy nano-mipsel to your device"
echo "2. chmod +x nano-mipsel"
echo "3. mv nano-mipsel /usr/local/bin/nano"
echo "4. Set TERM environment variable: export TERM=linux"
echo ""
echo "If you get 'Error opening terminal' when running nano:"
echo "Run: export TERM=linux"
echo "Or add to ~/.bashrc: echo 'export TERM=linux' >> ~/.bashrc"
