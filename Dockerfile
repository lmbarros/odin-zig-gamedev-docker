#
# odin-zig-gamedev-docker
#

# 24.04 LTS Noble Numbat
FROM ubuntu:noble-20250127

# Environment setup
RUN <<EOF
apt-get update
apt-get install -y binutils cmake curl git make pkgconf unzip xz-utils zip
EOF

# Please bind-mount this one!
WORKDIR /game

# Install Odin
RUN <<EOF
cd /opt
curl -L https://github.com/odin-lang/Odin/releases/download/dev-2025-01/odin-ubuntu-amd64-dev-2025-01.zip > /tmp/odin.zip
unzip -p /tmp/odin.zip | tar xvz
rm /tmp/odin.zip
mv odin-linux-amd64* odin
ln -s /opt/odin/odin /usr/bin
EOF

# Install Zig
RUN <<EOF
cd /opt
curl -L https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz | tar xvJ
mv zig-linux* zig
ln -s /opt/zig/zig /usr/bin
EOF

# Build some of the Odin vendored libs. Apparently compilation of modules
# importing those fail even when building with `mode:obj` if they binaries are
# not found.
RUN <<EOF
cd /opt/odin/vendor/box2d/
CC="zig cc" CXX="zig c++" ./build_box2d.sh

cd /opt/odin/vendor/miniaudio/src
CC="zig cc" make
EOF

# Dependencies paths
RUN <<EOF
mkdir -p /deps/x86_64-linux/lib

mkdir -p /deps/x86_64-windows/lib
mkdir -p /deps/x86_64-windows/bin
EOF


#
# SDL 2
#

# Optional dependencies for nicer SDL builds under Linux.
RUN apt-get install -y libgl-dev
RUN apt-get install -y libx11-dev libxext-dev
RUN apt-get install -y wayland-utils libwayland-dev libegl-dev libxkbcommon-dev
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
curl -L https://github.com/libsdl-org/SDL/releases/download/release-2.32.0/SDL2-2.32.0.tar.gz | tar xvz
cd SDL2-2.32.0
CC="zig cc" CFLAGS="-I/usr/include -L/lib/x86_64-linux-gnu -O3 -target x86_64-linux-gnu -march=nehalem" ./configure
make
cp -r build/.libs/*.so* /deps/x86_64-linux/lib
make install
rm -rf /tmp/SDL2-2.32.0
EOF

# Windows
RUN <<EOF
cd /tmp
curl -L https://github.com/libsdl-org/SDL/releases/download/release-2.32.0/SDL2-devel-2.32.0-mingw.tar.gz | tar xvz
cp /tmp/SDL2-2.32.0/x86_64-w64-mingw32/lib/libSDL2.dll.a /deps/x86_64-windows/lib
cp /tmp/SDL2-2.32.0/x86_64-w64-mingw32/bin/SDL2.dll /deps/x86_64-windows/bin
chmod 444 /deps/x86_64-windows/*/*
rm -rf /tmp/SDL2-2.32.0/
EOF


#
# SDL2_ttf
#

# Linux
RUN <<EOF
cd /tmp
curl -L https://github.com/libsdl-org/SDL_ttf/releases/download/release-2.24.0/SDL2_ttf-2.24.0.tar.gz | tar xvz
cd SDL2_ttf-2.24.0
CC="zig cc" CFLAGS="-I/usr/include -L/lib/x86_64-linux-gnu -O3 -target x86_64-linux-gnu -march=nehalem" CXX="zig c++" CXXFLAGS="-I/opt/zig/lib/libcxx/include -L/lib/x86_64-linux-gnu -O3 -target x86_64-linux-gnu -march=nehalem" ./configure
make
cp -r .libs/*.so* /deps/x86_64-linux/lib
rm -rf /tmp/SDL2_ttf-2.24.0
EOF

# Windows
RUN <<EOF
cd /tmp
curl -L https://github.com/libsdl-org/SDL_ttf/releases/download/release-2.24.0/SDL2_ttf-devel-2.24.0-mingw.tar.gz | tar xvz
cp /tmp/SDL2_ttf-2.24.0/x86_64-w64-mingw32/lib/libSDL2_ttf.dll.a /deps/x86_64-windows/lib
cp /tmp/SDL2_ttf-2.24.0/x86_64-w64-mingw32/bin/SDL2_ttf.dll /deps/x86_64-windows/bin
chmod 444 /deps/x86_64-windows/*/*
rm -rf /tmp/SDL2_ttf-2.24.0
EOF


#
# SDL2_image
#

# Linux
RUN <<EOF
cd /tmp
curl -L https://github.com/libsdl-org/SDL_image/releases/download/release-2.8.5/SDL2_image-2.8.5.tar.gz | tar xvz
cd SDL2_image-2.8.5
CC="zig cc" CFLAGS="-I/usr/include -L/lib/x86_64-linux-gnu -O3 -target x86_64-linux-gnu -march=nehalem" CXX="zig c++" CXXFLAGS="-I/opt/zig/lib/libcxx/include -L/lib/x86_64-linux-gnu -O3 -target x86_64-linux-gnu -march=nehalem" ./configure
make
cp -r .libs/*.so* /deps/x86_64-linux/lib
rm -rf /tmp/SDL2_image-2.8.5
EOF

# Windows
RUN <<EOF
cd /tmp
curl -L https://github.com/libsdl-org/SDL_image/releases/download/release-2.8.5/SDL2_image-devel-2.8.5-mingw.tar.gz | tar xvz
cp /tmp/SDL2_image-2.8.5/x86_64-w64-mingw32/lib/libSDL2_image.dll.a /deps/x86_64-windows/lib
cp /tmp/SDL2_image-2.8.5/x86_64-w64-mingw32/bin/SDL2_image.dll /deps/x86_64-windows/bin
chmod 444 /deps/x86_64-windows/*/*
rm -rf /tmp/SDL2_image-2.8.5
EOF


#
# miniaudio
#

RUN <<EOF
set -e

cd /tmp
curl -L https://github.com/mackron/miniaudio/archive/refs/tags/0.11.21.tar.gz | tar xvz
cd miniaudio-0.11.21
echo "#define MINIAUDIO_IMPLEMENTATION\\n#include \"miniaudio.h\"" > miniaudio.c

# Linux
zig cc -c -O3 -target x86_64-linux-gnu -march=nehalem -fno-sanitize=undefined miniaudio.c
zig ar rcs libminiaudio.a miniaudio.o
cp libminiaudio.a /deps/x86_64-linux/lib
rm miniaudio.o

# Windows
zig cc -c -O3 -target x86_64-windows-gnu -march=nehalem -fno-sanitize=undefined miniaudio.c
zig ar rcs libminiaudio.a miniaudio.obj
cp libminiaudio.a /deps/x86_64-windows/lib

rm -rf /tmp/miniaudio-0.11.21
EOF


#
# Box2D
#

RUN <<EOF
cd /tmp
curl -L https://github.com/erincatto/box2d/archive/refs/tags/v3.0.0.tar.gz | tar xvz
cd box2d-3.0.0/src

# Linux
for f in *.c; do
	zig cc -c -O3 -target x86_64-linux-gnu -march=nehalem -I ../include -I ../extern/simde/ $f
done
zig ar rcs libbox2d.a *.o
cp libbox2d.a /deps/x86_64-linux/lib
rm *.o

# Windows
for f in *.c; do
	zig cc -c -O3 -target x86_64-windows-gnu -march=nehalem -I ../include -I ../extern/simde/ $f
done
zig ar rcs libbox2d.a *.obj
cp libbox2d.a /deps/x86_64-windows/lib
rm -rf /tmp/box2d-3.0.0
EOF


#
# Hack: define _fltused (Windows-only)
#

RUN <<EOF
mkdir /tmp/fltused
cd /tmp/fltused
echo "int _fltused = 1;" > fltused.c
zig cc -c -O3 -target x86_64-windows-gnu -march=nehalem fltused.c
zig ar rcs libfltused.a fltused.obj
cp libfltused.a /deps/x86_64-windows/lib
rm -rf /tmp/fltused
EOF
