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
/usr/local/bin/python3 $this_dir/../misc/env_analyser.py $@
