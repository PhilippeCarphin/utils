#!/usr/bin/env -S bash -o errexit -o nounset -o errtrace -o pipefail -O inherit_errexit -O nullglob -O extglob

set -x

case $1 in -h|--help) echo "$0 SUBJECT EMAIL CMD [ARGS...]" ; exit 0 ;; esac

subject=$1 ; shift
email=$1 ; shift

if ! tmpdir=$(mktemp -d $PWD/tmp_output_${1}_XXXXXX) ; then
	echo "Could not create tmpdir"
	exit 1
fi

launch_date="$(date)"
launch_date_UNIX="$(date +%s)"
bash -lc "$*" > ${tmpdir}/stdout 2>${tmpdir}/stderr
status=$?
end_date="$(date)"
end_date_UNIX="$(date +%s)"

time=$((end_date_UNIX - launch_date_UNIX))
hours=$((time / 3600))
minutes=$(( (time % 3600) / 60))
time_str="${hours}h${minutes}m"

mail -s "${subject}" ${email} <<-EOF
	The command '${*}' has completed

	Status: ${status}
	Start time: ${launch_date}
	End time: ${end_date}
	Duration: ${time_str}
	PWD: ${PWD}

	Stdout:
$(tail -n 8 ${tmpdir}/stdout | sed 's/^/\t\t/')
	Stderr:
$(tail -n 8 ${tmpdir}/stderr | sed 's/^/\t\t/')

	Listings in: ${tmpdir}
EOF

