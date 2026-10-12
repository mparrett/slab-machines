#!/bin/sh
# Link this checkout's chip machine into Slab's user machines folder, so
# edits here show up the next time Slab loads it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
machines="${SLAB_HOME:-$HOME/Music/Slab}/Machines"
mkdir -p "$machines"
if [ -e "$machines/chip" ] && [ ! -L "$machines/chip" ]; then
    echo "$machines/chip exists and isn't a link; move it aside first" >&2
    exit 1
fi
ln -sfn "$here/chip" "$machines/chip"
echo "linked $machines/chip -> $here/chip"
