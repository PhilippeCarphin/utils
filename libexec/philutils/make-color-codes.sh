#!/bin/bash

################################################################################
# Main function called at end of this script
################################################################################
main(){
    echo "============= Basic colors : \033[<n>m ======================="
    printf "\033[4mBasic Foreground\033[0m\n"
    list 30 37
    printf "\033[4mBasic Background\033[0m\n"
    list 40 47
    printf "\033[4mBright Basic Foreground\033[0m\n"
    list 90 97
    printf "\033[4mBright Basic Background\033[0m\n"
    list 100 107

    echo "============= 8 bit color : \033[48;5;<n>m ======================="
    echo "The same color can be set for the foreground using \033[38;5;<n>m"

    echo "============= 6x6x6 cube"
    print-cube

    echo "============= Grayscale values"
    rectangle 232 4 6

    echo "============= Basic 16 colors"
    echo "Same as \033[<30-37>m for foreground and \033[<40-47>m for background"
    row 0 8  # +1 because row does ${1} <= x < ${2}
    echo "Same as \033[<90-97>m for foreground and \033[<100-107>m for background"
    row 8 16

}
################################################################################
# Prints the color cube
################################################################################
print-cube() {
    echo "Printing each code as 'printf \"\033[48;5;\${code}m\${zero_padded_code}\033[0m\"\'
with code in [16,231] = 16 + (36r + 6g + b) with r,g,b in [0,5].  Note that the RGB values
0x00(0), 0x5f(95), 0x87(135), 0xaf(175), 0xd7(215), 0xff(255) are not evenly spaced.
The jumps are 95, 40, 40, 40, 40."
# Maybe https://www.ditig.com/256-colors-cheat-sheet
# http://www.calmar.ws/vim/256-xterm-24bit-rgb-color-chart.html
# code-16 % 36 is the left-right index
# code-16 / 36 is the vertical index
# (code-16) % 6 is the inner horizontal index

echo "
           blue
red|00 5f 87 af d7 ff|"
    for ul in 16 52 88 124 160 196 ; do
        case $ul in 16) red=00 ;; 52) red=5f;; 88)red=87;; 124)red=af;; 160)red=d7;; 196)red=ff;; esac
        echo -n  "$red :"
        row $ul $(($ul + 36))
    done
    echo '    \________________/\________________/\________________/\________________/\________________/\________________/
green       00                5f                87                af                d7                ff
'
}

################################################################################
# Pads to three digits by adding leading '0's
################################################################################
zero-pad-to-3-digits () {
    local number=$1
    if (($number < 10)) ; then
        echo 00$number
    elif (( $number < 100 )) ; then
        echo 0$number
    else
        echo $number
    fi
}

print_code(){
    local code=$1
    if (( code <= 255 )) && (( 232 <= code)) ; then
        if (( 248 <= code )) && (( code <= 255 )) ; then
            fg=$'\033[38;5;0m'
        else
            fg=$'\033[38;5;15m'
        fi
        printf "\033[48;5;${code}m${fg}$(zero-pad-to-3-digits ${code} )\033[0m"
        # printf "\033[48;5;${code}m${fg}   \033[0m"
    else
        if (( 24 <= ((code - 16) % 36) )) ; then
            fg=$'\033[38;5;0m'
        else
            fg=$'\033[38;5;15m'
        fi
        if [[ -n ${grayscale} ]] ; then
            # Testing ANSI colorcube to ANSI grayscale [232,255]
            gcode=$(ansi_to_grayscale ${code})
            printf "\033[48;5;${gcode}m${fg}   \033[0m"
        else
            printf "\033[48;5;${code}m${fg}$(zero-pad-to-3-digits ${code} )\033[0m"
        fi

    fi
}

map=(0 95 135 175 215 255)
# Code from [16,231] (code is 16 + 36r + 6g + b where r,g,b in [0,5])
# And [0,5] --map--> [0,255]
# [0,255]x[0,255]x[0,255] ---> [0,255] with 0.3*R + 0.59*G + 0.11*B
# [0,255] ---> [232,255] (range of grayscale ansi codes)
ansi_to_grayscale(){
    local ansi=$1
    if (( ansi < 16 )) ||((ansi > 231)) ; then
        return 1
    fi

    # Extract r,g,b from ansi = 16 + 36r + 6g + b (r,g,b in [0,5])
    ansi=$((ansi-16))
    local b=$((ansi % 6))
    local g=$(( (ansi/6) % 6 ))
    local r=$(( (ansi/36) ))

    # Use gray = 0.3R + 0.59G + 0.11B (R,G,B in [0,255]
    local gray=$(( (30*map[r] + 59*map[g] + 11*map[b]) / 100 ))
    # Map [0,255] to [232,255]
    local code=$((232 + (gray * (255-232))/255))
    echo "${code}"
}

################################################################################
# Prints a row of color codes from i0 to i1
################################################################################
row () {
    local i0=$1
    local i1=$2
    for ((j=$i0;j<$i1;j++)) ; do
        print_code $j
    done
    printf "\033[0m\n"
}

################################################################################
# Prints a rectangle of codes
################################################################################
rectangle () {
    local upper_left=$1
    local M=$2
    local N=$3
    for ((i=0;i<$M;i++)) ; do
        for ((j=0;$j<$N;j++)) ; do
            code=$(($upper_left + ($N * $i) + $j))
            print_code $code
        done
        printf "\033[0m\n"
    done
}

################################################################################
# Prints one color per line with more detail
#     (white on color)(color on black)(black on color)
################################################################################
list() {
    local start=$1
    local finish=$2
    for ((i=$start; i<=$finish; i++)) ; do
        #echo -n "${i} : "$'\033['${i}mlorem ipsum$'\033[0m'
        printf "${i} : \033[${i}mlorem ipsum\033[0m\n"
        # echo ""
    done
}

main
