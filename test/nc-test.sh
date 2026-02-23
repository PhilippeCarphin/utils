# vim: noet:ts=8:sw=8:sts=8:listchars=lead\:·,trail\:·,tab\:\ \ ,space\:\ :
{
	cat <<-EOF
		POST / HTTP/1.1
		Access-Control-Allow-Origin: *
		Content-type: text/event-stream
		Transfer-Encoding: chunked
		BingBong: b64

	EOF
	# Send just the chunk 'asdfasdf'
	printf "8\r\nasdfasdf\r\n"
	# Send just a newline
	# - Send the size of the chunk
	printf "1\r\n"
	# - Send the content of the chunk
	printf "\n"
	# - Followed by "\r\n"
	printf "\r\n"

	# Send the word "apple"
	printf "5\r\napple\r\n"

	printf "NOTE: Reading from STDIN\n" >&2
	printf "NOTE: Send a 0 chunk size to end communication\n" >&2
	printf "NOTE: then press C-c to \"close\" STDIN\n" >&2
	printf "NOTE: We can't (easily) send '\\\\r' interactively some servers are OK with that some not\n" >&2
	# Start reading from stdin to play around
	cat
} | nc "$@"

