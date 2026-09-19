color_step=37
color_start=21
color_step=17
color_end=226
color=$color_start
declare -A colors


main(){
    local field=${1:-3}
    local header=${2:-0}
    local lineno=0
    while IFS=$'\n' read line ; do
        lineno=$((lineno+1))
        if ((lineno <= header)) ; then
            printf "%s\n" "${line}"
            continue
        fi
        words=()
        split-line line words
        add-color-at-index words $field
        printf "%s" "${words[@]}"
        printf "\n"
    done
}

_split-line-getchar(){
    if ((i>=len)) ; then
        return 1
    fi
    c=${_line:i++:1}
}

_split-line-internal(){
    while true ; do
        if ! _split-line-getchar ; then return ; fi
        word+=$c
        if [[ $c != ' ' ]] ; then
            break
        fi
    done

    while true ; do
        while true ; do
            if ! _split-line-getchar ; then return ; fi
            word+=$c
            if [[ $c == ' ' ]] ; then
                break
            fi
        done

        while true ; do
            if ! _split-line-getchar ; then return ; fi
            if [[ $c == ' ' ]] ; then
                word+=$c
            else
                _words+=("${word}")
                word=$c
                break
            fi
        done
    done
}

split-line(){
    local -n _line=$1
    local -n _words=$2
    _words=()

    local word=''
    local i=0
    local len=${#_line}
    local c

    _split-line-internal
    _words+=("${word}")
}

add-color-at-index(){
    local -n _words=$1
    local index=$2
    key=${_words[index]}
    c=${colors[$key]}
    if [[ -z ${c} ]] ; then
        color=$((color+color_step))
        if ((color >= color_end));then
            color=$color_start
        fi
        c=$'\033[38;5;'"${color}m"
        colors[$key]="$c"
    fi
    _words[index]="${c}${_words[index]}"$'\033[0m'
}

color-cycle(){
    local start=$1
    local max=$2
    local step=$3
    local count=${4:-15}
    local current=$start
    local i
    for((i=0;i<count;i++)); do
        printf "\e[38;5;${current}mCOLOR $current\e[0m\n"
        current=$((current+step))
        if ((current >= max)) ; then
            current=$start
        fi
    done
}

main "$@"
exit


while IFS=$'\n' read line ; do
    len=${#line}
    word=''
    words=()
    i=0
    # Add leading delimiters to first word
    while true ; do
        # c=${line:i++:1} ; if ((i>len)) ; then words+=("${word}") break ; fi
        if ! getchar ; then
        word+=$c
        if [[ $c != ' ' ]] ; then
            break
        fi
    done

    # Normal processing
    while true ; do

        # Add non-delimiters to current word until a delimiter is found
        # which is also added to the word
        while true ; do
            c=${line:i++:1} ; if ((i>len)) ; then words+=("${word}") break 2 ; fi
            word+=$c
            if [[ $c == ' ' ]] ; then
                break
            fi
        done

        # Add all following delimiters to the current word until a non-delimiter
        # is found.  At this point, start a new word with that character
        while true ; do
            c=${line:i++:1} ; if ((i>len)) ; then words+=("${word}") break 2 ; fi
            if [[ $c == ' ' ]] ; then
                word+=$c
            else
                words+=("${word}")
                word=$c
                break
            fi
        done
    done
    words+=("${word}")

    key=${words[field]}
    c=${colors[$key]}
    if [[ -z ${c} ]] ; then
        color=$(($color+9))
        if ((color > 231));then
            color=57
        fi
        c=$'\033[38;5;'"${color}m"
        colors[$key]="$c"
    fi

    if [[ -n ${DEBUG} ]] ; then
        declare -p words
    fi
    words[field]="${c}${words[field]}"$'\033[0m'
    # declare -p words
    printf "%s" "${words[@]}"
    printf "\n"
done
