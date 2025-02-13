#!/bin/sh
echo -ne '\033c\033]0;mountainVille\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/linuxMountainVille.x86_64" "$@"
