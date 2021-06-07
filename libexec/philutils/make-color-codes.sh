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
    echo -n "$(tput setab $code)$(reformat_number $code)$(tput sgr 0)"
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
    echo $(tput sgr 0)
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
        echo $(tput sgr 0)
    done
}

################################################################################
# Prints one color per line with more detail
#     (white on color)(color on black)(black on color)
################################################################################
list() {
    start=$1
    finish=$2
    for ((i=$start; i<$finish; i++)) ; do
        print_code $i
        echo -n $(tput setaf $i)"lorem ipsup"$(tput sgr 0)
        echo -n $(tput setaf 0)
        print_code $i
        echo ""
    done
}

############################ PRINTING SEQUENCE #################################
echo "
           blue
red|00 5f 87 af d7 ff|"
for ul in 16 52 88 124 160 196 ; do
    case $ul in 16) red=00 ;; 52) red=5f;; 88)red=87;; 124)red=af;; 160)red=d7;; 196)red=ff;; esac
    echo -n  "$red :"
    row $ul $(($ul + 36))
done
echo "\
    \________________/\________________/\________________/\________________/\________________/\________________/
green       00                5f                87                af                d7                ff
"

rectangle 232 4 6
echo ""

list 0 16
