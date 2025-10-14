philutils_root=$(cd -P $(dirname ${BASH_SOURCE[0]})/../../ && pwd)
enable -f ${philutils_root}/libexec/philutils/my-builtins.so shell_split
