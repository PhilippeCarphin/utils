philutils_setup_my_builtins(){
    local philutils_root=$(cd -P $(dirname ${BASH_SOURCE[0]})/../../ && pwd)
    local philutils_my_builtins=${philutils_root}/libexec/philutils/my-builtins.so
    if [[ -f ${philutils_my_builtins} ]] ; then
        enable -f ${philutils_my_builtins} shell_split
    fi
}
philutils_setup_my_builtins ; unset -f $_
