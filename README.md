# Building nano for MIPS Little-Endian Architecture (Creality 3D Printers)

This guide explains how to cross-compile the nano text editor for MIPS little-endian embedded systems, specifically tested on Creality Ender 3D printers running Linux with Ingenic XBurst2 processors.

## Download pre-compiled MIPS nano v7.2
- Download the binary from the releases page
- Ensure executability with ```bash chmod +x nano-mipsel```
- Place in the correct directory for manually installed executables (depends on system)
- Create a bash alias or simply rename the file to "nano"

## Prerequisites

- Debian 12 (bookworm) or similar modern Linux distribution
- Root access or sudo privileges
- Internet connection for downloading source packages

## Quick Start (Automated)

```bash
# Download and run the build script
wget https://example.com/build-nano-mips.sh
chmod +x build-nano-mips.sh
sudo ./build-nano-mips.sh
```

The compiled binary will be at `/tmp/mips-build/nano-mipsel`.

## Manual Process

### 1. Install Build Dependencies

```bash
sudo apt update
sudo apt install -y gcc-mipsel-linux-gnu g++-mipsel-linux-gnu wget build-essential texinfo
```

**Explanation:**
- `gcc-mipsel-linux-gnu`: Cross-compiler for MIPS little-endian architecture
- `texinfo`: Required for building nano's documentation
- `build-essential`: Standard compilation tools (make, etc.)

### 2. Create Workspace

```bash
mkdir -p /tmp/mips-build
cd /tmp/mips-build
```

### 3. Build ncurses Library

ncurses provides terminal control functionality that nano requires.

```bash
# Download and extract ncurses
wget https://ftp.gnu.org/gnu/ncurses/ncurses-6.4.tar.gz
tar -xzf ncurses-6.4.tar.gz
cd ncurses-6.4

# Configure for MIPS little-endian cross-compilation
./configure \
    --host=mipsel-linux-gnu \
    --prefix=/tmp/mips-build/mips-sysroot \
    --enable-static \
    --disable-shared \
    --without-debug \
    --without-tests \
    --without-cxx-binding \
    --with-normal \
    --disable-widec \
    --with-fallbacks=linux,screen,vt100,xterm \
    CC=mipsel-linux-gnu-gcc

# Build and install
make -j$(nproc)
make install
```

**Key configure options:**
- `--host=mipsel-linux-gnu`: Target MIPS little-endian architecture
- `--enable-static`: Create static library (no runtime dependencies)
- `--disable-widec`: Disable wide character support (reduces size)
- `--with-fallbacks`: Include basic terminal definitions for common terminals

### 4. Fix ncurses Header Structure

The ncurses headers reference files in a nested directory structure that needs to be created:

```bash
cd /tmp/mips-build/mips-sysroot/include/ncurses
mkdir -p ncurses

# Create symbolic links for all headers in nested directory
for f in *.h; do
    ln -sf ../$f ncurses/$f
done
```

**Why this is needed:** nano's source expects ncurses headers to be available both as `curses.h` and `ncurses/curses.h`, but our ncurses build only creates the flat structure.

### 5. Build nano

```bash
cd /tmp/mips-build

# Download and extract nano
wget https://www.nano-editor.org/dist/v7/nano-7.2.tar.xz
tar -xf nano-7.2.tar.xz
cd nano-7.2

# Configure for MIPS little-endian with static linking
PKG_CONFIG_PATH="/tmp/mips-build/mips-sysroot/lib/pkgconfig" \
./configure \
    --host=mipsel-linux-gnu \
    --prefix=/usr/local \
    --disable-nls \
    --disable-utf8 \
    --enable-tiny \
    CC=mipsel-linux-gnu-gcc \
    CPPFLAGS="-I/tmp/mips-build/mips-sysroot/include/ncurses" \
    LDFLAGS="-L/tmp/mips-build/mips-sysroot/lib -static"

# Build
make -j$(nproc)
```

**Key configure options:**
- `--host=mipsel-linux-gnu`: Target MIPS little-endian (crucial for Ingenic processors)
- `--disable-nls`: No internationalization (reduces size)
- `--disable-utf8`: No UTF-8 support (reduces size)
- `--enable-tiny`: Minimal feature set
- `LDFLAGS="-static"`: Create standalone binary

**Expected warnings during build:**
- Compiler warnings about braces in signal_init function (harmless)
- Linker warnings about getpwent/getpwuid in static applications (harmless)

### 6. Verify and Copy Binary

```bash
# Copy to a convenient location
cp src/nano /tmp/mips-build/nano-mipsel

# Check binary format (if hexdump available)
hexdump -C /tmp/mips-build/nano-mipsel | head -1
# Should show: 7f 45 4c 46 01 01 01 00 (note the "01 01" for little-endian)
```

## Installing on Target Device

### 1. Transfer and Install Binary

Transfer the binary to your MIPS device (via SCP, USB, web interface, etc.), then:

```bash
chmod +x nano-mipsel
mv nano-mipsel /usr/local/bin/nano
```

### 2. Fix Terminal Environment

If you get "Error opening terminal" when running nano:

```bash
# Temporary fix
export TERM=linux
nano test.txt

# Permanent fix - add to shell profile
echo 'export TERM=linux' >> ~/.bashrc
```

**Why this is needed:** Many SSH clients (like Alacritty) set TERM to their own value, but embedded systems don't have those terminal definitions. The fallback terminals we compiled into ncurses (linux, xterm, vt100) will work.

### 3. Test Installation

```bash
nano --version
nano test.txt
```

## Troubleshooting

### Architecture Issues

**"ELF file data encoding not little-endian"**
- You compiled for big-endian MIPS instead of little-endian
- Use `mipsel-linux-gnu-gcc` not `mips-linux-gnu-gcc`
- Rebuild with the correct toolchain

**"syntax error unexpected ("**
- Binary format mismatch or corruption during transfer
- Check with: `hexdump -C nano-mipsel | head -1`
- Should start with `7f 45 4c 46 01 01`

### Terminal Issues

**"Error opening terminal: [terminal-name]"**
- Set TERM to a supported terminal: `export TERM=linux`
- Available fallbacks: linux, screen, vt100, xterm

### Build Issues

**Missing texinfo**: Install with `apt install texinfo`
**Missing ncurses headers**: Ensure the header symlinks were created correctly
**Permission denied**: Ensure binary is executable with `chmod +x`

## System Compatibility

### Verified Compatible Systems
- Creality Ender 3D printers with Ingenic XBurst2 processors
- Linux kernel 4.4.94+ 
- MIPS little-endian architecture

### Checking Your System
```bash
uname -m                    # Should show "mips"
cat /proc/cpuinfo | grep model  # Should show Ingenic or similar
hexdump -C /bin/ls | head -1     # Should show "01 01" for little-endian
```

## Notes

- This process creates a static binary (~1MB) with no external dependencies
- The same process can be adapted for other programs by replacing the nano build steps
- Static linking warnings about glibc functions are normal and harmless
- The minimal ncurses build includes only essential terminal types to reduce size
