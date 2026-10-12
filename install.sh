#!/bin/sh
# Link this checkout's machines into Slab's user machines folder, so edits
# here show up the next time Slab loads them. With no arguments, every
# machine (a <console>/<id>/<id>.fy); otherwise only the ids named.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
machines="${SLAB_HOME:-$HOME/Music/Slab}/Machines"
mkdir -p "$machines"
for manifest in "$here"/*/*/*.fy; do
    dir=$(dirname "$manifest")
    id=$(basename "$dir")
    [ "$(basename "$manifest" .fy)" = "$id" ] || continue
    if [ $# -gt 0 ]; then
        case " $* " in *" $id "*) ;; *) continue ;; esac
    fi
    if [ -e "$machines/$id" ] && [ ! -L "$machines/$id" ]; then
        echo "$machines/$id exists and isn't a link; move it aside first" >&2
        exit 1
    fi
    ln -sfn "$dir" "$machines/$id"
    echo "linked $machines/$id -> $dir"
done
