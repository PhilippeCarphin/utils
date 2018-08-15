ssh $(echo $SSH_CLIENT | cut -d ' ' -f 1) emacsclient --no-wait $@
