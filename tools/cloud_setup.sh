#!/usr/bin/env bash
# Installs what tools/check.py needs in a Claude Code cloud session (Ubuntu, as root):
# Godot, its Web export templates, uv, and a `godot` wrapper that gives windowed runs
# (check.py capture) a virtual display. The cloud environment's setup script runs it
# (README.md, Setup › Cloud sessions). Safe to run again: it skips what is installed.
set -euo pipefail

# Bump together with GODOT_VERSION in tools/check.py. The hashes are the release's
# SHA512-SUMS.txt lines for the two files.
GODOT_VERSION=4.7.2
GODOT_SHA512=9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65
TEMPLATES_SHA512=ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079
# From the release's uv-x86_64-unknown-linux-gnu.tar.gz.sha256.
UV_VERSION=0.11.32
UV_SHA256=aab924fd522efd06f1c5f3b93a243864fc453132c94b2dc49f1371b528a4b967

RELEASE=https://github.com/godotengine/godot-builds/releases/download/$GODOT_VERSION-stable
BINARY_NAME=Godot_v$GODOT_VERSION-stable_linux.x86_64
# The environment variables let a test install somewhere else.
GODOT_DIR=${GODOT_DIR:-/opt/godot}
BIN_DIR=${BIN_DIR:-/usr/local/bin}
# Where Godot looks for templates on Linux.
TEMPLATES_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$GODOT_VERSION.stable
# Godot's runtime libraries for a window, and the tools this script uses.
PACKAGES=(xvfb xauth libgl1 libgl1-mesa-dri libglx-mesa0 libfontconfig1 libxcursor1 libxinerama1
  libxrandr2 libxi6 curl unzip ca-certificates)

fail() {
  echo "cloud_setup: $*" >&2
  exit 1
}

# Run from a checkout, compare the pin with check.py's.
check_py=$(dirname "${BASH_SOURCE[0]:-.}")/check.py
if [ -f "$check_py" ] && ! grep -qx "GODOT_VERSION = \"$GODOT_VERSION\"" "$check_py"; then
  fail "GODOT_VERSION here ($GODOT_VERSION) differs from $check_py"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Large downloads through the cloud session's proxy sometimes reset mid-transfer, so an
# interrupted one resumes where it stopped (-C -) instead of starting over.
download() { # <url> <file, saved in $work>
  echo "cloud_setup: downloading $1"
  local attempt
  for attempt in 1 2 3 4 5 6; do
    curl -fsSL --retry 3 -C - -o "$work/$2" "$1" && return 0
    echo "cloud_setup: download interrupted (attempt $attempt), resuming" >&2
    sleep $((attempt * 2))
  done
  fail "download failed: $1"
}

verify() { # <sha256|sha512> <hash> <file in $work>
  echo "$2  $work/$3" | "${1}sum" --quiet -c - || fail "$1 mismatch: $3"
}

missing=()
for package in "${PACKAGES[@]}"; do
  dpkg -s "$package" >/dev/null 2>&1 || missing+=("$package")
done
if [ ${#missing[@]} -gt 0 ]; then
  [ "$(id -u)" = 0 ] || fail "run as root to install ${missing[*]}"
  echo "cloud_setup: installing ${missing[*]}"
  apt-get update -q
  DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends "${missing[@]}"
fi

mkdir -p "$BIN_DIR"
if command -v uv >/dev/null; then
  echo "cloud_setup: uv already installed"
else
  archive=uv-x86_64-unknown-linux-gnu.tar.gz
  download "https://github.com/astral-sh/uv/releases/download/$UV_VERSION/$archive" "$archive"
  verify sha256 "$UV_SHA256" "$archive"
  tar -xzf "$work/$archive" -C "$work"
  install -m 755 "$work/uv-x86_64-unknown-linux-gnu/uv" "$work/uv-x86_64-unknown-linux-gnu/uvx" "$BIN_DIR/"
fi

binary=$GODOT_DIR/$BINARY_NAME
if [ -x "$binary" ] && [[ $("$binary" --headless --version) == "$GODOT_VERSION.stable."* ]]; then
  echo "cloud_setup: Godot $GODOT_VERSION already installed"
else
  download "$RELEASE/$BINARY_NAME.zip" "$BINARY_NAME.zip"
  verify sha512 "$GODOT_SHA512" "$BINARY_NAME.zip"
  unzip -q -o "$work/$BINARY_NAME.zip" -d "$work"
  mkdir -p "$GODOT_DIR"
  install -m 755 "$work/$BINARY_NAME" "$binary"
fi

# Windowed runs (capture) need a display. Without one, run them under Xvfb.
cat >"$BIN_DIR/godot" <<WRAPPER
#!/bin/bash
# Written by tools/cloud_setup.sh.
if [ -z "\${DISPLAY:-}" ] && [[ " \$* " != *" --headless "* ]] && [[ " \$* " != *" --version "* ]]; then
  exec xvfb-run -a -s "-screen 0 1920x1080x24" "$binary" "\$@"
fi
exec "$binary" "\$@"
WRAPPER
chmod 755 "$BIN_DIR/godot"

# The archive holds every platform's templates (1.3 GB). Keep only the Web ones.
if [ "$(cat "$TEMPLATES_DIR/version.txt" 2>/dev/null)" = "$GODOT_VERSION.stable" ] &&
  [ -f "$TEMPLATES_DIR/web_nothreads_release.zip" ] &&
  [ -f "$TEMPLATES_DIR/web_nothreads_debug.zip" ]; then
  echo "cloud_setup: Web export templates already installed"
else
  archive=Godot_v$GODOT_VERSION-stable_export_templates.tpz
  download "$RELEASE/$archive" "$archive"
  verify sha512 "$TEMPLATES_SHA512" "$archive"
  unzip -q -o "$work/$archive" 'templates/web_*' templates/version.txt -d "$work"
  rm "$work/$archive"
  mkdir -p "$TEMPLATES_DIR"
  mv -f "$work"/templates/* "$TEMPLATES_DIR/"
fi

found=$("$BIN_DIR/godot" --headless --version) || fail "$BIN_DIR/godot does not run"
[[ $found == "$GODOT_VERSION.stable."* ]] || fail "$BIN_DIR/godot is $found, not $GODOT_VERSION"
echo "cloud_setup: done, Godot $found, templates in $TEMPLATES_DIR"
