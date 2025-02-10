#
# odin-zig-gamedev-docker
#

# 24.04 LTS Noble Numbat
FROM ubuntu:noble-20250127

# Environment setup
RUN <<EOF
apt-get update
apt-get install -y curl unzip xz-utils make
EOF

WORKDIR /opt

# Install Odin
RUN <<EOF
curl -L https://github.com/odin-lang/Odin/releases/download/dev-2025-01/odin-ubuntu-amd64-dev-2025-01.zip > /tmp/odin.zip
unzip -p /tmp/odin.zip | tar xvz
rm /tmp/odin.zip
mv odin-linux-amd64* odin
ln -s /opt/odin/odin /usr/bin
EOF

# Install Zig
RUN <<EOF
curl -L https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz | tar xvJ
mv zig-linux* zig
ln -s /opt/zig/zig /usr/bin
EOF
