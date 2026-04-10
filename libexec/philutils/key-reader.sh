#!/usr/bin/env -S bash -o errexit -o nounset -o errtrace -o pipefail -O inherit_errexit -O nullglob -O extglob

stty intr ''
stty quit ''
stty kill ''
stty eof ''
stty start ''
stty stop ''
stty susp ''
stty rprnt ''
stty werase ''
stty lnext ''
stty discard ''

while read -s -N 1 b ; do
    printf "(((%q)))\n" "${b}"
    case "$b" in
        $'\003')
            printf "C-c pressed: quitting\n" ; exit 130 ;;
        $'\e')
            read -r -s -t 0.1 -n 2 bing || true
            printf "<<<%q>>>\n" "${bing}"
            case "$bing" in
                '[A') printf "up-arrow-bing-bong\n" ;;
                '[B') printf "down-arrow-bing-bong\n" ;;
                '') printf "escape-BING-BONG\n" ;;
            esac
            ;;
    esac
done
