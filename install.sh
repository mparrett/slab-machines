#!/bin/sh
# Link this checkout's machines into Slab's user machines folder, so edits
# here show up the next time Slab loads them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
machines="${SLAB_HOME:-$HOME/Music/Slab}/Machines"
mkdir -p "$machines"
for m in sdsp sdspecho opn psg opndac; do
    if [ -e "$machines/$m" ] && [ ! -L "$machines/$m" ]; then
        echo "$machines/$m exists and isn't a link; move it aside first" >&2
        exit 1
    fi
    ln -sfn "$here/$m" "$machines/$m"
    echo "linked $machines/$m -> $here/$m"
done
