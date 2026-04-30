#!/usr/bin/env -S bash -o errexit -o nounset -o errtrace -o pipefail -O inherit_errexit -O nullglob -O extglob

saved_stty_settings=$(stty -g)
trap "stty '${saved_stty_settings}'" EXIT

if [[ $(uname) == Darwin ]] ; then
    stty dsusp ''
    stty reprint ''
    stty status ''
fi

# I don't know what these do but they are in the cchars section
# of stty report on MacOS
stty min '0'
stty time '0'

stty discard ''
stty eof ''
stty erase ''
stty intr ''
stty kill ''
stty lnext ''
stty quit ''
stty rprnt ''
stty start ''
stty stop ''
stty susp ''
stty werase ''

declare -gA key_map=(
    # C-qwertyuiop
    [$'\021']="C-q" [$'\027']="C-w" [$'\005']="C-e" [$'\022']="C-r"
    [$'\024']="C-t" [$'\031']="C-y" [$'\025']="C-u" [$'\t']="C-i/TAB"
    [$'\017']="C-o" [$'\020']="C-p"

    # C-asdfghjkl
    [$'\001']="C-a" [$'\023']="C-s" [$'\004']="C-d" [$'\006']="C-f"
    [$'\a']="C-g" [$'\b']="C-h" [$'\v']="C-k"
    [$'\f']="C-l"

    # C-zxcvbnm,./
    [$'\032']="C-z" [$'\030']="C-x" [$'\003']="C-c" [$'\026']="C-v"
    [$'\002']="C-b" [$'\016']="C-n" [$'\n']="C-m/C-j/Enter" [$'\,']="," [$'\.']="."
    [$'\037']="C-/"
)

printf "Waiting for key presses ...\n"
while read -s -N 1 byte ; do
    case "$byte" in
        $'\003')
            read -p "C-c pressed: quit? y/n > " answer
            if [[ ${answer} == y* ]] ; then kill -INT $$ ; fi ;;
        $'\e')
            read -r -s -t 0.1 -n 2 bytes_after_esc || true
            case "$bytes_after_esc" in
                '[A') printf "byte: %s (sent by pressing up-arrow)\n"    "\\E$bytes_after_esc" ;;
                '[B') printf "byte: %s (sent by pressing down-arrow)\n"  "\\E$bytes_after_esc" ;;
                '[C') printf "byte: %s (sent by pressing right-arrow)\n" "\\E$bytes_after_esc" ;;
                '[D') printf "byte: %s (sent by pressing left-arrow)\n"  "\\E$bytes_after_esc" ;;
                '') printf "byte: %s (sent by pressing ESC\n"            "\\E"      ;;
                *) printf "byte: \\E$bytes_after_esc (sent by pressing 'ESC ${bytes_after_esc}' or 'ALT-$bytes_after_esc)\n" ;;
            esac
            ;;
        *)  if [[ -n "${key_map[$byte]:-}" ]] ; then
                printf "byte:%q (sent by pressing ${key_map[$byte]})\n" "$byte"
            else
                printf "byte:%q\n" "$byte"
            fi
    esac
done
