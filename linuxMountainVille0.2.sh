#!/bin/sh
echo -ne '\033c\033]0;mountainVille\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/linuxMountainVille0.2.x86_64" "$@"
