#!/usr/bin/env bash
#
map=(0 95 135 175 215 255) # [0,5] |--> [0,255]
declare -A pow_6=([red]=36 [green]=6 [blue]=1)

usage(){
    printf "USAGE:\n\n\t${0##*/} [-c CODE1 CODE2 | -l R1 G1 B1 R2 G2 B2 | -a]

    -c CODE1 CODE2: Print a line on the cube from CODE1 to CODE2
    -l R1 G1 B1 R2 G2 B2: Print a line on the cube from (R1,G1,B1) to (R2,G2,B2)
                          with Ri Gi Bi in [0,5]
    -a: Print extra faces and cube organized in various ways
    -x CODE: Display code as hex RGB values\n"
}
################################################################################
# Main function called at end of this script
################################################################################
main(){
    local OPTIND OPTARG opt
    local line_codes=false
    local line_rgb=false
    local all=false
    local code_to_hex=false
    local code_to_cube=false
    local code=
    while getopts "hclx:u:a" opt ; do
        case ${opt} in
            c) line_codes=true ;;
            l) line_rgb=true ;;
            a) all=true ;;
            x) code_to_hex=true ; code=${OPTARG#0} ;;
            u) code_to_cube=true ; code=${OPTARG#0} ;;
            h) usage ; return 0 ;;
            '?') usage ; return 1;;
        esac
    done
    shift $((OPTIND-1))

    if ${code_to_cube} ; then
        display-code-rgb ${code}
        return
    fi

    if ${code_to_hex} ; then
        display-code-hex-rgb ${code}
        return
    fi

    if ${line_rgb} ; then
        if (( $# < 6 )) ; then
            printf "ERROR: With -l 6 arguments must be given: $0 -l R1 G1 B1 R2 G2 B2"
            return 1
        fi
        display-line-rgb "$@"
        return
    fi

    if ${line_codes} ; then
        if (( $# < 2 )) ; then
            printf "ERROR: With -c 2 arguments must be given: $0 -c CODE1 CODE2"
            return 1
        fi
        display-line-code "$@"
        return
    fi

    echo "============= Basic colors : \033[<n>m ======================="
    printf "\033[4mBasic Foreground\033[0m\n"
    list 30 37
    printf "\033[4mBasic Background\033[0m\n"
    list 40 47
    printf "\033[4mBright Basic Foreground\033[0m\n"
    list 90 97
    printf "\033[4mBright Basic Background\033[0m\n"
    list 100 107

    echo "============= 8 bit color : \033[48;5;<n>m \033[38;5;<n>m ==========="
    echo "48 is background, 38 is foreground"
    echo "============= [0,15] Basic 16 colors"
    echo "Same as \033[<30-37>m for foreground and \033[<40-47>m for background"
    row 0 8  # +1 because row does ${1} <= x < ${2}
    echo "Same as \033[<90-97>m for foreground and \033[<100-107>m for background"
    row 8 16


    echo "============= [16,231] 6x6x6 cube"
    print-cube

    if ${all} ; then
        echo "============= Extra faces"
        print-extra-ways
    fi

    echo "============= [232,255] Grayscale values"
    rectangle 232 4 6

}
print-extra-ways(){
    printf " ----- RG face with B=0\n"
    print_face rg 0
    printf " ----- RG face with B=5\n"
    print_face rg 5
    printf " ----- RG face with R=0\n"
    print_face gb 0
    printf " ----- GB face with R=5\n"
    print_face gb 5
    printf " ----- BR cube\n"
    print_x_cube br
    printf " ----- RG cube\n"
    print_x_cube rg
    printf " ----- BG cube\n"
    print_x_cube bg
}

print_face(){
    local pow_i pow_j pow_fix
    case $1 in
        rg) pow_i=red  ;   pow_j=green;    pow_k=blue  ;;
        rb) pow_i=red  ;   pow_k=green ;   pow_j=blue  ;;
        gr) pow_i=green;   pow_j=red  ;    pow_k=blue  ;;
        gb) pow_k=red  ;   pow_i=green;    pow_j=blue  ;;
        br) pow_i=blue ;   pow_k=green ;   pow_j=red   ;;
        bg) pow_k=red  ;   pow_i=blue ;    pow_j=green ;;
    esac
    local k=$2
    for j in {0..5} ; do
        for i in {0..5} ; do
                print_code $((16 + i*pow_6[$pow_i] + j*pow_6[$pow_j] + k*pow_6[$pow_k]))
        done
        printf "\n"
    done
}
#
# Print as a cube of XY faces
#  ______ ______ ______ ______ ______ ______
# |+-i-->|      |      |      |      |      |
# ||     |      |      |      |      |      |
# |j     |      |      |      |      |      |
# ||     |      |      |      |      |      |
# |v_____|______|______|______|______|______|
# |
# |---------------- k (faces) -------------->
#
print_x_cube(){
    local pow_i pow_j pow_k
    case $1 in
        rg) pow_i=red  ;   pow_j=green ;    pow_k=blue  ;;
        rb) pow_i=red  ;   pow_k=green ;    pow_j=blue  ;;
        gr) pow_i=green;   pow_j=red   ;    pow_k=blue  ;;
        gb) pow_k=red  ;   pow_i=green ;    pow_j=blue  ;;
        br) pow_i=blue ;   pow_k=green ;    pow_j=red   ;;
        bg) pow_k=red  ;   pow_i=blue  ;    pow_j=green ;;
    esac
    local values=(00 5f 87 af d7 ff)
    # printf "     %s\n" "${1:0:1}"
    # printf "%-3s |00  5f  87  af  d7  ff |\n"
    for j in {0..5} ; do
        # printf " %s " "${values[j]}"
        for k in {0..5} ; do
            for i in {0..5} ; do
                print_code $((16 + i*pow_6[$pow_i] + j*pow_6[$pow_j] + k*pow_6[$pow_k]))
            done
        done
        printf "\n"
   done
   # echo '    \__________00 _________/\__________5f__________/\__________87__________/\__________af__________/\__________d7__________/\__________ff__________/'
}
################################################################################
# Prints the color cube
################################################################################
print-cube() {
#     echo "Printing each code as 'printf \"\033[48;5;\${code}m\${zero_padded_code}\033[0m\"\'
# with code in [16,231] = 16 + (36r + 6g + b) with r,g,b in [0,5].  Note that the RGB values
# 0x00(0), 0x5f(95), 0x87(135), 0xaf(175), 0xd7(215), 0xff(255) are not evenly spaced.
# The jumps are 95, 40, 40, 40, 40."
# Maybe https://www.ditig.com/256-colors-cheat-sheet
# http://www.calmar.ws/vim/256-xterm-24bit-rgb-color-chart.html
# code-16 % 36 is the left-right index
# code-16 / 36 is the vertical index
# (code-16) % 6 is the inner horizontal index
echo "           blue
red|00  5f  87  af  d7  ff |"
    for ul in 16 52 88 124 160 196 ; do
        case $ul in 16) red=00 ;; 52) red=5f;; 88)red=87;; 124)red=af;; 160)red=d7;; 196)red=ff;; esac
        echo -n  "$red :"
        row $ul $(($ul + 36))
    done
    echo '    \______________________/\______________________/\______________________/\______________________/\______________________/\______________________/
green         00                      5f                      87                      af                      d7                      ff'
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

select-fg(){
    local code=$1
    if (( 232 <= code)) && (( code <= 255 )) ; then
        if (( 248 <= code )) ; then
            echo $'\033[38;5;0m'
        else
            echo $'\033[38;5;15m'
        fi
    else
        if (( 24 <= ((code - 16) % 36) )) ; then
            echo $'\033[38;5;0m'
        else
            echo $'\033[38;5;15m'
        fi
    fi
}


print_code(){
    local code=$1
    if (( 232 <= code)) && (( code <= 255 )) ; then
        if (( 248 <= code )) ; then
            fg=$'\033[38;5;0m'
        else
            fg=$'\033[38;5;15m'
        fi
    else
        if (( 24 <= ((code - 16) % 36) )) ; then
            fg=$'\033[38;5;0m'
        else
            fg=$'\033[38;5;15m'
        fi
    fi

    if [[ -n ${grayscale} ]] ; then
        # Testing ANSI colorcube to ANSI grayscale [232,255]
        gcode=$(ansi_to_grayscale ${code})
        printf "\033[48;5;${gcode}m${fg}    \033[0m"
    else
        printf "\033[48;5;%dm${fg} %03d\033[0m" "${code}" "${code}"
    fi


}

map=(0 95 135 175 215 255) # [0,5] |--> [0,255]

# Code from [16,231] (code is 16 + 36r + 6g + b where r,g,b in [0,5])
# And [0,5] --map--> [0,255]
# [0,255]x[0,255]x[0,255] ---> [0,255] with 0.3*R + 0.59*G + 0.11*B
# [0,255] ---> [232,255] (range of grayscale ansi codes)
# ansi in [16,230]
ansi_to_grayscale(){
    local ansi=$1
    if ((ansi > 232)) ; then
        echo $ansi
        return
    fi

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

display-rgb-code(){
    r=$1
    g=$2
    b=$3

    code=$(rgb-to-code $r $g $b)
    # printf "\033[38;5;%dm%03d\033[0m\n" "${code}" "${code}"
    # printf "\033[1;37;48;5;%dm %03d\033[0m" "${code}" "${code}"
    print_code "${code}"
}

display-code-rgb(){
    local code=$1
    local rgb=($(code-to-rgb ${code}))
    local fg="$(select-fg ${code})"
    printf "${fg}\033[48;5;${code}m%d,%d,%d\033[0m\n" "${rgb[0]}" "${rgb[1]}" "${rgb[2]}"
}

display-code-hex-rgb(){
    local code=$1
    display-rgb-hex $(code-to-rgb ${code})
}

display-rgb-hex(){
    r=$1
    g=$2
    b=$3

    code=$(rgb-to-code $r $g $b)
    local fg=$(select-fg ${code})
    printf "${fg}\033[48;5;${code}m0x%02x%02x%02x\033[0m\n" "${map[r]}" "${map[g]}" "${map[b]}"
}

display-line-rgb(){
    local r1=$1 g1=$2 b1=$3
    local r2=$4 g2=$5 b2=$6

    for ((i=0; i<6; i++)) ; do
        # printf "%d,%d,%d\n" $((r1 + i*(r2 - r1)/5 )) \
        #                     $((g1 + i*(g2 - g1)/5 )) \
        #                     $((b1 + i*(b2 - b1)/5 )) >&2

        display-rgb-code $((r1 + i*(r2 - r1)/5 )) \
                         $((g1 + i*(g2 - g1)/5 )) \
                         $((b1 + i*(b2 - b1)/5 ))
    done
    printf "\n"
}

code-to-rgb(){
    local code=$1
    local x=$((code-16))
    local r=$(( (x/${pow_6[red]})   % 6 ))
    local g=$(( (x/${pow_6[green]}) % 6 ))
    local b=$(( (x/${pow_6[blue]})  % 6 ))
    echo $r $g $b
}

rgb-to-code(){
    local r=$1 g=$2 b=$3
    echo $((16 + $r*${pow_6[red]} + $g*${pow_6[green]} + $b*${pow_6[blue]}))
}

display-line-code(){
    local c1=${1##0}
    local c2=${2##0}

    local d1=( $(code-to-rgb $c1) )
    local d2=( $(code-to-rgb $c2) )

    display-line-rgb ${d1[0]} ${d1[1]} ${d1[2]} \
                     ${d2[0]} ${d2[1]} ${d2[2]}
}


# main "$@"
# display-line-rgb 0 0 0 0 0 5
# # code-to-rgb 46
# # code-to-rgb 21
# # code-to-rgb 160

main "$@"
