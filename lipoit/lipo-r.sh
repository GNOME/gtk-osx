#!/bin/bash

# Ivan Levashew, 5 Dec 2007
# Public Domain License
# Free to use in any way, personal or commercial

# Usage:
# lipo-r startdir "arch1 arch2 ..." unidir


for i in $2; do
        REF_ARCH="$i"
        break
done

ref_root="$1/$REF_ARCH"
#LIPO_DEBUG="echo"

echo "lipo-ing..."

lipo_internal () {
        local i j l

        $LIPO_DEBUG mkdir -p "$3$4"

        for i in "${ref_root}$4"/*; do
                j="${i:${#ref_root}}"
                if [ -d "$i" ]; then
                        lipo_internal "$1" "$2" "$3" "$j"
                elif [ -L "$i" ]; then
                        $LIPO_DEBUG ln -s "`readlink "$i"`" "$3$j"
                else
                        ((file -b "$i" | grep -q text) || (file -b "$i" | grep -q byte-compiled ) || (( file -b "$i" | grep -q i386) && ( file -b "$i" | grep -q ppc ))) && {
                                $LIPO_DEBUG cp "$i" "$3$j"
                        } || {
                                unset k
                                local -a k
                                for l in $2; do
                                        k[${#k[@]}]="-arch"
                                        k[${#k[@]}]="$l"
                                        k[${#k[@]}]="$1/$l$j"
                                done
                                $LIPO_DEBUG lipo -create "${k[@]}" -output "$3$j"
                        }
                fi
        done
}

lipo_internal "$1" "$2" "$3"