p.type () 
{ 
    local type_py=$(cd $(dirname ${BASH_SOURCE[0]})/../../libexec/philutils && pwd)/type.py
    ( set -o pipefail;
    if ! declare -f "$1" | python3 ${type_py} ; then
        type "$@";
    fi )
}
