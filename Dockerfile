#
# odin-zig-gamedev-docker
#

# ------------------------------------------------------------------------------
#  Build stage
# ------------------------------------------------------------------------------

# 22.04 LTS Jammy Jellyfish
#
# Using the previous Ubuntu LTS (24.04 Noble Numbat is already out) because I
# want to have the binaries depending on the older glibc version (specifically,
# glibc 2.35, released on 2022-02-03). Too many people are still on systems
# using older glibc versions, so we better be compatible with those!
#
# Worth noting:
#
# * With 24.04 Noble Numbat I used to have `-target x86_64-linux-gnu` in
#   `CFLAGS` when building SDL. Doesn't seem to play well with 22.04 LTS Jammy
#   Jellyfish. Shouldn't be necessary, as we are not cross-compiling.
FROM ubuntu:jammy-20250730 AS build

# Versions and stuff.
ARG ODIN_VERSION=dev-2025-09
ARG ZIG_VERSION=0.14.1
ARG ZIG_MACOS_SDK_VERSION=a4ea24f105902111633c6ae9f888b676ac5e36df
ARG SDL_VERSION=2.32.8
ARG SDL_TTF_VERSION=2.24.0
ARG SDL_IMAGE_VERSION=2.8.8
ARG MINIAUDIO_VERSION=0.11.22
ARG BOX2D_VERSION=3.1.0

ARG OPT_FLAGS_PC=-O3 -march=nehalem
ARG OPT_FLAGS_MAC=-O3

# Environment setup
RUN <<EOF
apt-get update
apt-get install -y 7zip binutils clang cmake curl git make pkgconf unzip xz-utils zip

# We install SDL and friends, too. Even though we'll not use these for the
# packaged releases, having those in standard locations make it simpler to
# run simple builds.
apt-get install -y libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev
EOF

# Install Odin
RUN <<EOF
cd /opt
curl -L https://github.com/odin-lang/Odin/releases/download/${ODIN_VERSION}/odin-linux-amd64-${ODIN_VERSION}.zip > /tmp/odin.zip
unzip -p /tmp/odin.zip | tar xvz
rm /tmp/odin.zip
mv odin-linux-amd64* odin
ln -s /opt/odin/odin /usr/bin
EOF

# Install Zig
RUN <<EOF
cd /opt
curl -L https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz | tar xvJ
mv zig-x86_64-linux* zig
ln -s /opt/zig/zig /usr/bin
EOF

# Download macOS SDK files for use with Zig
RUN <<EOF
cd /opt/
git clone https://github.com/mitchellh/zig-build-macos-sdk.git
cd zig-build-macos-sdk
git checkout ${ZIG_MACOS_SDK_VERSION}
EOF

# Build some of the Odin vendored libs for Linux. Apparently compilation of
# modules importing those fail even when building with `mode:obj` if the
# binaries are not found.
RUN <<EOF
cd /opt/odin/vendor/box2d/
CC="zig cc" CXX="zig c++" ./build_box2d.sh

cd /opt/odin/vendor/miniaudio/src
CC="zig cc" make
EOF

# Since Odin 2025-09, the Windows binaries for vendor libraries are no longer
# included in the Linux package. So, we download the Windows package and get
# these binaries from there. (We need these, otherwise the Windows builds will
# fail even when building with `mode:obj` -- as noted above for Linux).
RUN <<EOF
mkdir /tmp/win/

curl -L https://github.com/odin-lang/Odin/releases/download/${ODIN_VERSION}/odin-windows-amd64-${ODIN_VERSION}.zip > /tmp/win/odin_windows.zip
cd /tmp/win
unzip odin_windows.zip

cp vendor/box2d/lib/*.lib /opt/odin/vendor/box2d/lib/
cp vendor/miniaudio/lib/*.lib /opt/odin/vendor/miniaudio/lib/

rm -rf /tmp/win
EOF

# Dependencies paths
RUN <<EOF
mkdir -p /deps/x86_64-linux/lib

mkdir -p /deps/x86_64-windows/lib
mkdir -p /deps/x86_64-windows/bin

mkdir -p /deps/x86_64-macos-none/lib
EOF


#
# SDL 2
#

# Optional dependencies for nicer SDL builds under Linux.
RUN apt-get install -y libgl-dev
RUN apt-get install -y libx11-dev libxext-dev
RUN apt-get install -y libwayland-dev libegl-dev libxkbcommon-dev
RUN apt-get install -y libasound-dev
RUN apt-get install -y libpulse-dev
RUN apt-get install -y libpipewire-0.3-dev
RUN apt-get install -y libjack-dev
RUN apt-get install -y libsndio-dev
RUN apt-get install -y libxcursor-dev
RUN apt-get install -y libxi-dev
RUN apt-get install -y libxrandr-dev
RUN apt-get install -y libxss-dev
RUN apt-get install -y libdrm-dev libgbm-dev
RUN apt-get install -y libgbm-dev

# Linux
RUN <<EOF
cd /tmp
curl -L https://github.com/libsdl-org/SDL/releases/download/release-${SDL_VERSION}/SDL2-${SDL_VERSION}.tar.gz | tar xvz
cd SDL2-${SDL_VERSION}
CC="zig cc" CFLAGS="-I/usr/include -L/lib/x86_64-linux-gnu ${OPT_FLAGS_PC}" ./configure
make
strip -g build/.libs/*.so*
cp -r build/.libs/*.so* /deps/x86_64-linux/lib
make install
rm -rf /tmp/SDL2-${SDL_VERSION}
EOF

# Windows
RUN <<EOF
cd /tmp
curl -L https://github.com/libsdl-org/SDL/releases/download/release-${SDL_VERSION}/SDL2-devel-${SDL_VERSION}-mingw.tar.gz | tar xvz
cp /tmp/SDL2-${SDL_VERSION}/x86_64-w64-mingw32/lib/libSDL2.dll.a /deps/x86_64-windows/lib
cp /tmp/SDL2-${SDL_VERSION}/x86_64-w64-mingw32/bin/SDL2.dll /deps/x86_64-windows/bin
chmod 444 /deps/x86_64-windows/*/*
rm -rf /tmp/SDL2-${SDL_VERSION}/
EOF

# macOS
RUN <<EOF
curl -L https://github.com/libsdl-org/SDL/releases/download/release-${SDL_VERSION}/SDL2-${SDL_VERSION}.dmg > /tmp/SDL2-${SDL_VERSION}.dmg
cd /tmp
7zz x SDL2-${SDL_VERSION}.dmg
cp SDL2/SDL2.framework/Versions/Current/SDL2 /deps/x86_64-macos-none/lib/SDL2.o
rm -rf /tmp/SDL2-${SDL_VERSION}.dmg /tmp/SDL2
EOF


#
# SDL2_ttf
#

# Linux
RUN <<EOF
cd /tmp
curl -L https://github.com/libsdl-org/SDL_ttf/releases/download/release-${SDL_TTF_VERSION}/SDL2_ttf-${SDL_TTF_VERSION}.tar.gz | tar xvz
cd SDL2_ttf-${SDL_TTF_VERSION}
CC="zig cc" CFLAGS="-I/usr/include -L/lib/x86_64-linux-gnu ${OPT_FLAGS_PC}" CXX="zig c++" CXXFLAGS="-I/opt/zig/lib/libcxx/include -L/lib/x86_64-linux-gnu ${OPT_FLAGS_PC}" ./configure
make
strip -g .libs/*.so*
cp -r .libs/*.so* /deps/x86_64-linux/lib
rm -rf /tmp/SDL2_ttf-${SDL_TTF_VERSION}
EOF

# Windows
RUN <<EOF
cd /tmp
curl -L https://github.com/libsdl-org/SDL_ttf/releases/download/release-${SDL_TTF_VERSION}/SDL2_ttf-devel-${SDL_TTF_VERSION}-mingw.tar.gz | tar xvz
cp /tmp/SDL2_ttf-${SDL_TTF_VERSION}/x86_64-w64-mingw32/lib/libSDL2_ttf.dll.a /deps/x86_64-windows/lib
cp /tmp/SDL2_ttf-${SDL_TTF_VERSION}/x86_64-w64-mingw32/bin/SDL2_ttf.dll /deps/x86_64-windows/bin
chmod 444 /deps/x86_64-windows/*/*
rm -rf /tmp/SDL2_ttf-${SDL_TTF_VERSION}
EOF

# macOS
RUN <<EOF
curl -L https://github.com/libsdl-org/SDL_ttf/releases/download/release-${SDL_TTF_VERSION}/SDL2_ttf-${SDL_TTF_VERSION}.dmg > /tmp/SDL2_ttf-${SDL_TTF_VERSION}.dmg
cd /tmp
7zz x SDL2_ttf-${SDL_TTF_VERSION}.dmg
cp SDL2_ttf/SDL2_ttf.framework/Versions/Current/SDL2_ttf /deps/x86_64-macos-none/lib/SDL2_ttf.o
rm -rf /tmp/SDL2_ttf-${SDL_TTF_VERSION}.dmg /tmp/SDL2_ttf
EOF


#
# SDL2_image
#

# Linux
RUN <<EOF
cd /tmp
curl -L https://github.com/libsdl-org/SDL_image/releases/download/release-${SDL_IMAGE_VERSION}/SDL2_image-${SDL_IMAGE_VERSION}.tar.gz | tar xvz
cd SDL2_image-${SDL_IMAGE_VERSION}
CC="zig cc" CFLAGS="-I/usr/include -L/lib/x86_64-linux-gnu ${OPT_FLAGS_PC}" CXX="zig c++" CXXFLAGS="-I/opt/zig/lib/libcxx/include -L/lib/x86_64-linux-gnu ${OPT_FLAGS_PC}" ./configure
make
strip -g .libs/*.so*
cp -r .libs/*.so* /deps/x86_64-linux/lib
rm -rf /tmp/SDL2_image-${SDL_IMAGE_VERSION}
EOF

# Windows
RUN <<EOF
cd /tmp
curl -L https://github.com/libsdl-org/SDL_image/releases/download/release-${SDL_IMAGE_VERSION}/SDL2_image-devel-${SDL_IMAGE_VERSION}-mingw.tar.gz | tar xvz
cp /tmp/SDL2_image-${SDL_IMAGE_VERSION}/x86_64-w64-mingw32/lib/libSDL2_image.dll.a /deps/x86_64-windows/lib
cp /tmp/SDL2_image-${SDL_IMAGE_VERSION}/x86_64-w64-mingw32/bin/SDL2_image.dll /deps/x86_64-windows/bin
chmod 444 /deps/x86_64-windows/*/*
rm -rf /tmp/SDL2_image-${SDL_IMAGE_VERSION}
EOF

# macOS
RUN <<EOF
curl -L https://github.com/libsdl-org/SDL_image/releases/download/release-${SDL_IMAGE_VERSION}/SDL2_image-${SDL_IMAGE_VERSION}.dmg > /tmp/SDL2_image-${SDL_IMAGE_VERSION}.dmg
cd /tmp
7zz x SDL2_image-${SDL_IMAGE_VERSION}.dmg
cp SDL2_image/SDL2_image.framework/Versions/Current/SDL2_image /deps/x86_64-macos-none/lib/SDL2_image.o
rm -rf /tmp/SDL2_image-${SDL_IMAGE_VERSION}.dmg /tmp/SDL2_image
EOF


#
# miniaudio
#

RUN <<EOF
set -e

cd /tmp
curl -L https://github.com/mackron/miniaudio/archive/refs/tags/${MINIAUDIO_VERSION}.tar.gz | tar xvz
cd miniaudio-${MINIAUDIO_VERSION}
echo "#define MINIAUDIO_IMPLEMENTATION\\n#include \"miniaudio.h\"" > miniaudio.c

# Linux
zig cc -c -target x86_64-linux-gnu ${OPT_FLAGS_PC} -fno-sanitize=undefined miniaudio.c
zig ar rcs libminiaudio.a miniaudio.o
strip -g miniaudio.o
mv libminiaudio.a /deps/x86_64-linux/lib
rm miniaudio.o

# Windows
zig cc -c -target x86_64-windows-gnu ${OPT_FLAGS_PC} -fno-sanitize=undefined miniaudio.c
zig ar rcs libminiaudio.a miniaudio.obj
mv libminiaudio.a /deps/x86_64-windows/lib
rm miniaudio.obj

# macOS
zig cc -c -target x86_64-macos-none ${OPT_FLAGS_MAC} -fno-sanitize=undefined -iframework /opt/zig-build-macos-sdk/Frameworks miniaudio.c
mkdir /deps/x86_64-macos-none/lib/miniaudio
mv miniaudio.o /deps/x86_64-macos-none/lib/miniaudio

rm -rf /tmp/miniaudio-${MINIAUDIO_VERSION}
EOF


#
# Box2D
#

RUN <<EOF
cd /tmp
curl -L https://github.com/erincatto/box2d/archive/refs/tags/v${BOX2D_VERSION}.tar.gz | tar xvz
cd box2d-${BOX2D_VERSION}/src

# Linux
for f in *.c; do
	zig cc -c -target x86_64-linux-gnu ${OPT_FLAGS_PC} -I ../include -I ../extern/simde/ $f
done
strip -g *.o
zig ar rcs libbox2d.a *.o
mv libbox2d.a /deps/x86_64-linux/lib
rm *.o

# Windows
for f in *.c; do
	zig cc -c -target x86_64-windows-gnu ${OPT_FLAGS_PC} -I ../include -I ../extern/simde/ $f
done
zig ar rcs libbox2d.a *.obj
mv libbox2d.a /deps/x86_64-windows/lib
rm *.obj

# macOS
for f in *.c; do
	zig cc -c -target x86_64-macos-none ${OPT_FLAGS_MAC} -I ../include -I ../extern/simde/ $f
done
mkdir /deps/x86_64-macos-none/lib/box2d
mv *.o /deps/x86_64-macos-none/lib/box2d

rm -rf /tmp/box2d-${BOX2D_VERSION}
EOF


#
# Hack: define _fltused (Windows-only)
#

RUN <<EOF
mkdir /tmp/fltused
cd /tmp/fltused
echo "int _fltused = 1;" > fltused.c
zig cc -c -target x86_64-windows-gnu ${OPT_FLAGS_PC} fltused.c
zig ar rcs libfltused.a fltused.obj
mv libfltused.a /deps/x86_64-windows/lib
rm -rf /tmp/fltused
EOF


# ------------------------------------------------------------------------------
#  Final stage
# ------------------------------------------------------------------------------

FROM ubuntu:jammy-20250730

# Please bind-mount your project root dir to /game when using the image.
WORKDIR /game

# Copy stuff we built on the previous stage.
COPY --from=build /deps /deps
COPY --from=build /opt /opt

RUN <<EOF
# The Ubuntu Jammy image doesn't include a non-root user, so we create one
# mimicking what we have for more recent releases.
groupadd ubuntu
useradd -ms /bin/bash -g ubuntu ubuntu

# Make our shiny new compilers are usable.
ln -s /opt/odin/odin /usr/bin
ln -s /opt/zig/zig /usr/bin

# Install stuff we'll need when using the image.
apt-get update
apt-get install -y clang git make zip
EOF
