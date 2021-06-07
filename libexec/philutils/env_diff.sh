this_file=$0
while [ -L $this_file ] ; do
    this_link=$(readlink $this_file)
    if [[ $this_link == .* ]] || [[ $this_link == ..* ]] ; then
        this_dir=$(dirname $this_file)
        this_file=$this_dir/$this_link
    else
        this_file=$this_link
    fi
done
this_dir=$(cd -P $(dirname $this_file) > /dev/null && pwd)
env_before_file=/tmp/$(whoami)_env_before.txt
env_after_file=/tmp/$(whoami)_env_after.txt
$this_dir/env_analyser.sh dump > $env_before_file
eval $@
$this_dir/env_analyser.sh dump > $env_after_file

$this_dir/env_analyser.sh compare $env_before_file $env_after_file
