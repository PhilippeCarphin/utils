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
    number=$1
    if (($number < 10)) ; then
        echo 00$number
    elif (( $number < 100 )) ; then
        echo 0$number
    else
        echo $number
    fi
}

print_code(){
    code=$1
    printf "\033[48;5;${code}m$(zero-pad-to-3-digits $code)\033[0m"
}

################################################################################
# Prints a row of color codes from i0 to i1
################################################################################
row () {
    i0=$1
    i1=$2
    for ((j=$i0;j<$i1;j++)) ; do
        print_code $j
    done
    printf "\033[0m\n"
}

################################################################################
# Prints a rectangle of codes
################################################################################
rectangle () {
    upper_left=$1
    M=$2
    N=$3
    for ((i=0;i<$M;i++)) ; do
        for ((j=0;$j<$N;j++)) ; do
            code=$(($upper_left + ($M * $i) + $j))
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
    start=$1
    finish=$2
    for ((i=$start; i<=$finish; i++)) ; do
        #echo -n "${i} : "$'\033['${i}mlorem ipsum$'\033[0m'
        printf "${i} : \033[${i}mlorem ipsum\033[0m\n"
        # echo ""
    done
}

main
