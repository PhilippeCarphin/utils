#!/bin/bash

################################################################################
# Pads to three digits by adding leading '0's
################################################################################
reformat_number () {
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
    printf "\033[48;5;${code}m$(reformat_number $code)\033[0m"
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
        echo -n "${i} : "$'\033['${i}mlorem ipsum$'\033[0m'
        echo ""
    done
}

############################ PRINTING SEQUENCE #################################
echo "
Using \033[48;5;\${code}\033[0m with code in [16,231] = 16 + (36r + 6g + b)
with r,g,b in [0,5]

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

rectangle 232 4 6
echo ""

printf "\033[4mBasic colors\033[0m\n"
list 30 37
printf "\033[4mBasic background\033[0m\n"
list 40 47
printf "\033[4mBright background\033[0m\n"
list 90 97
printf "\033[4mBright background\033[0m\n"
list 100 107
